variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC where ALB and EC2 will live"
  type        = string
  default     = "vpc-xxxxxxxx"
}

variable "alb_subnet_ids" {
  description = "Subnets for the ALB (must be at least two in different AZs)"
  type        = list(string)
  default     = ["subnet-aaaa1111", "subnet-bbbb2222"]
}

variable "app_subnet_ids" {
  description = "Subnets for EC2 instances (can be private if ALB has access)"
  type        = list(string)
  default     = ["subnet-aaaa1111", "subnet-bbbb2222"]
}

variable "alb_certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener"
  type        = string
  default     = "arn:aws:acm:us-east-1:123456789012:certificate/abcd-efgh"
}

variable "ssh_key_name" {
  description = "Existing EC2 key pair name for SSH"
  type        = string
  default     = "my-keypair"
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH into instances (lock to your IP)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "alb_allowed_cidr" {
  description = "CIDR allowed to reach the ALB (0.0.0.0/0 for public)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "instance_count" {
  description = "Number of FastAPI EC2 instances to place behind the ALB"
  type        = number
  default     = 2
}

variable "app_port" {
  description = "Port the FastAPI service listens on"
  type        = number
  default     = 8080
}

variable "app_user" {
  description = "Linux user that runs the FastAPI service"
  type        = string
  default     = "fastapi"
}

variable "app_env" {
  description = "Key/value pairs written to /opt/fastapi-app/.env"
  type        = map(string)
  default = {
    APP_ENV           = "prod"
    APP_DEBUG         = "false"
    DB_URL            = "postgresql://user:password@db.example.com:5432/app"
    AWS_REGION        = "us-east-1"
    S3_BUCKET         = "change-me-assets-bucket"
    DDB_TABLE         = "fastapi-ddb-table"
    SECRET_KEY        = "replace-me"
    ANOTHER_VARIABLE  = "value"
  }
}

variable "assets_bucket_name" {
  description = "Name of the S3 bucket used for public image storage"
  type        = string
  default     = "change-me-assets-bucket"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table for the application"
  type        = string
  default     = "fastapi-ddb-table"
}

variable "codedeploy_bucket_name" {
  description = "S3 bucket to store CodeDeploy application bundles"
  type        = string
  default     = "fastapi-codedeploy-artifacts"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project = "fastapi-alb"
    Owner   = "you@example.com"
  }
}
