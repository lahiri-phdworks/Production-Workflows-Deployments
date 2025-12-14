# Copy to terraform.tfvars and adjust
aws_region         = "us-east-1"
vpc_id             = "vpc-0123456789abcdef0"
alb_subnet_ids     = ["subnet-aaaa1111", "subnet-bbbb2222"]
app_subnet_ids     = ["subnet-aaaa1111", "subnet-bbbb2222"]
alb_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abcd-efgh-ijkl"
ssh_key_name       = "my-keypair-name"
ssh_allowed_cidr   = "203.0.113.10/32" # your IP
alb_allowed_cidr   = "0.0.0.0/0"
instance_type      = "t3.small"
instance_count     = 2
app_port           = 8080
app_user           = "fastapi"
assets_bucket_name = "my-fastapi-assets-bucket"
dynamodb_table_name = "fastapi-ddb-table"

app_env = {
  APP_ENV    = "prod"
  APP_DEBUG  = "false"
  SECRET_KEY = "replace-me"
  AWS_REGION = "us-east-1"
  S3_BUCKET  = "my-fastapi-assets-bucket"
  DDB_TABLE  = "fastapi-ddb-table"
  # Add DB_URL, API keys, etc.
}

tags = {
  Project = "fastapi-alb"
  Owner   = "team@example.com"
}
