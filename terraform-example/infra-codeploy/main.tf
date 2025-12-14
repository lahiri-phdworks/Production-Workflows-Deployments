data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "alb" {
  name        = "fastapi-alb-sg"
  description = "Allow inbound HTTP/HTTPS to ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.alb_allowed_cidr]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.alb_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "fastapi-alb-sg" })
}

resource "aws_security_group" "app" {
  name        = "fastapi-app-sg"
  description = "Allow ALB to reach app port and SSH from trusted CIDR"
  vpc_id      = var.vpc_id

  ingress {
    description      = "App from ALB"
    from_port        = var.app_port
    to_port          = var.app_port
    protocol         = "tcp"
    security_groups  = [aws_security_group.alb.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "fastapi-app-sg" })
}

resource "aws_lb" "app" {
  name               = "fastapi-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.alb_subnet_ids

  tags = merge(var.tags, { Name = "fastapi-alb" })
}

resource "aws_lb_target_group" "app" {
  name        = "fastapi-tg"
  port        = var.app_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = "/health"
    port                = var.app_port
    protocol            = "HTTP"
    unhealthy_threshold = 3
    healthy_threshold   = 2
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = merge(var.tags, { Name = "fastapi-tg" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

data "aws_iam_policy_document" "app_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "app_inline" {
  statement {
    sid     = "S3Access"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.assets.arn,
      "${aws_s3_bucket.assets.arn}/*"
    ]
  }

  statement {
    sid     = "DynamoDBAccess"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:ConditionCheckItem",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem"
    ]
    resources = [aws_dynamodb_table.app.arn]
  }
}

resource "aws_iam_role" "app" {
  name               = "fastapi-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.app_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "app" {
  name   = "fastapi-ec2-policy"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_inline.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role" "codedeploy_service" {
  name               = "fastapi-codedeploy-role"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "codedeploy_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy_managed" {
  role       = aws_iam_role.codedeploy_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

resource "aws_iam_instance_profile" "app" {
  name = "fastapi-ec2-profile"
  role = aws_iam_role.app.name
}

locals {
  user_data = templatefile("${path.module}/templates/user_data.tpl", {
    app_user = var.app_user
    app_port = var.app_port
    app_env  = var.app_env
    aws_region = var.aws_region
  })
}

resource "aws_instance" "app" {
  count                       = var.instance_count
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.instance_type
  subnet_id                   = element(var.app_subnet_ids, count.index % length(var.app_subnet_ids))
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = var.ssh_key_name
  iam_instance_profile        = aws_iam_instance_profile.app.name
  associate_public_ip_address = true
  user_data                   = local.user_data

  tags = merge(
    var.tags,
    {
      Name = "fastapi-app-${count.index + 1}"
      Role = "fastapi-app"
    }
  )
}

resource "aws_lb_target_group_attachment" "app" {
  count            = var.instance_count
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app[count.index].id
  port             = var.app_port
}

resource "aws_s3_bucket" "assets" {
  bucket        = var.assets_bucket_name
  force_destroy = true

  tags = merge(var.tags, { Name = "fastapi-assets" })
}

resource "aws_s3_bucket_ownership_controls" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "assets" {
  bucket = aws_s3_bucket.assets.id
  policy = templatefile("${path.module}/.bucket-policy", { bucket_name = aws_s3_bucket.assets.id })

  depends_on = [
    aws_s3_bucket_public_access_block.assets,
    aws_s3_bucket_ownership_controls.assets
  ]
}

resource "aws_dynamodb_table" "app" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "key1"
  range_key = "key2_sort"

  attribute {
    name = "key1"
    type = "S"
  }

  attribute {
    name = "key2_sort"
    type = "S"
  }

  tags = merge(var.tags, { Name = "fastapi-ddb" })
}

resource "aws_s3_bucket" "codedeploy_artifacts" {
  bucket        = var.codedeploy_bucket_name
  force_destroy = true

  tags = merge(var.tags, { Name = "fastapi-codedeploy-artifacts" })
}

resource "aws_s3_bucket_versioning" "codedeploy_artifacts" {
  bucket = aws_s3_bucket.codedeploy_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "codedeploy_artifacts" {
  bucket                  = aws_s3_bucket.codedeploy_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_codedeploy_app" "fastapi" {
  name             = "fastapi-codedeploy-app"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "fastapi" {
  app_name              = aws_codedeploy_app.fastapi.name
  deployment_group_name = "fastapi-codedeploy-dg"
  service_role_arn      = aws_iam_role.codedeploy_service.arn

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  ec2_tag_filter {
    key   = "Role"
    type  = "KEY_AND_VALUE"
    value = "fastapi-app"
  }
}
