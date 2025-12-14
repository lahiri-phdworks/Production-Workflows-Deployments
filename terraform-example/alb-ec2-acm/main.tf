############################
# Terraform & Provider
############################

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                   = var.aws_region
  profile                  = var.aws_profile
  shared_credentials_files = [var.aws_shared_credentials_file]
}

############################
# Variables
############################

variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile to use for authentications."
  type        = string
  default     = "default"
}

variable "aws_shared_credentials_file" {
  description = "Path to AWS shared credentials file"
  type        = string
  default     = "~/.aws/credentials"
}

variable "aws_ami_id" {
  description = "AMI ID to use for EC2 instances"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "ID of the VPC where ALB and EC2 will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB and EC2"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access (must already exist)"
  type        = string
  default     = ""
}

############################
# AMI (Amazon Linux 2 / 2023)
############################

data "aws_ami" "linux" {
  most_recent = true

  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20251022"]
  }
}

############################
# Security Groups
############################

# Security group for the ALB: allow HTTPS (443) from anywhere
resource "aws_security_group" "alb_sg" {
  name        = "alb-https-sg"
  description = "Allow HTTPS from the internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # (Optional) allow HTTP 80 if you want
  # ingress {
  #   description = "HTTP from anywhere"
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-https-sg"
  }
}

# Security group for the EC2 instance: allow port 8080 from ALB SG
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-app-8080-sg"
  description = "Allow app traffic from ALB on port 8080"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App port from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-app-8080-sg"
  }
}

############################
# EC2 Instance
############################

resource "aws_instance" "app" {
  count                  = 2
  ami                    = var.aws_ami_id != "" ? var.aws_ami_id : data.aws_ami.linux.id
  instance_type          = var.instance_type
  subnet_id              = element(var.public_subnet_ids, count.index % length(var.public_subnet_ids))
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = var.key_name != "" ? var.key_name : null

  associate_public_ip_address = true

  # Install and run FastAPI on port 8080 with instance-specific /health value
  user_data = <<-EOF
              #!/bin/bash
              set -euo pipefail
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -y
              apt-get install -y python3 python3-pip python3-venv

              APP_DIR=/opt/app
              VALUE=$((1500 + 1000*${count.index}))
              MSG="Hello ${count.index + 1}"

              rm -rf "$APP_DIR"
              mkdir -p "$APP_DIR"

              cat > "$APP_DIR/main.py" <<'PYAPP'
              from fastapi import FastAPI

              app = FastAPI()

              with open("/opt/app/value.txt") as f:
                  VALUE = int(f.read().strip())
              with open("/opt/app/message.txt") as f:
                  MSG = f.read().strip()

              from datetime import datetime

              @app.get("/health")
              def health():
                  return {
                      "value": VALUE,
                      "message": MSG,
                      "timestamp": datetime.utcnow().isoformat() + "Z",
                  }
              PYAPP

              echo "$VALUE" > "$APP_DIR/value.txt"
              echo "$MSG" > "$APP_DIR/message.txt"

              python3 -m venv "$APP_DIR/venv"
              "$APP_DIR/venv/bin/pip" install --upgrade pip
              "$APP_DIR/venv/bin/pip" install fastapi uvicorn

              cat > /etc/systemd/system/fastapi.service <<SERVICE
              [Unit]
              Description=FastAPI application
              After=network-online.target
              Wants=network-online.target

              [Service]
              WorkingDirectory=$APP_DIR
              ExecStart=$APP_DIR/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8080
              Restart=always
              RestartSec=5
              User=root
              Environment=PYTHONUNBUFFERED=1

              [Install]
              WantedBy=multi-user.target
              SERVICE

              systemctl daemon-reload
              systemctl enable fastapi
              systemctl start fastapi
              EOF

  tags = {
    Name = "app-ec2-instance-${count.index}"
  }

  root_block_device {
    volume_size = 80
    volume_type = "gp3"
  }
}

############################
# Load Balancer + Target Group
############################

resource "aws_lb" "app_alb" {
  name               = "app-alb-https"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "app-alb-https"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg-8080"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    path                = "/health"
    matcher             = "200"
  }

  tags = {
    Name = "app-tg-8080"
  }
}

# Attach EC2 instances to target group on port 8080
resource "aws_lb_target_group_attachment" "app_tg_attachment" {
  for_each          = { for idx, inst in aws_instance.app : idx => inst.id }
  target_group_arn  = aws_lb_target_group.app_tg.arn
  target_id         = each.value
  port              = 8080
}

############################
# HTTPS Listener
############################

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.app_tg.arn
      }
    }
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.app_tg.arn
      }
    }
  }
}

############################
# Outputs
############################

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.app_alb.dns_name
}

output "instance_public_ip" {
  description = "Public IPs of the EC2 instances"
  value       = aws_instance.app[*].public_ip
}
