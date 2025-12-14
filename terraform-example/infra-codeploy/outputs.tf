output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "alb_arn" {
  value = aws_lb.app.arn
}

output "target_group_arn" {
  value = aws_lb_target_group.app.arn
}

output "instance_public_ips" {
  value = aws_instance.app[*].public_ip
}

output "instance_private_ips" {
  value = aws_instance.app[*].private_ip
}

output "app_security_group_id" {
  value = aws_security_group.app.id
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "assets_bucket_name" {
  value = aws_s3_bucket.assets.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.app.name
}

output "codedeploy_bucket" {
  value = aws_s3_bucket.codedeploy_artifacts.bucket
}

output "codedeploy_app_name" {
  value = aws_codedeploy_app.fastapi.name
}

output "codedeploy_deployment_group" {
  value = aws_codedeploy_deployment_group.fastapi.deployment_group_name
}

output "app_user" {
  value = var.app_user
}

output "app_port" {
  value = var.app_port
}
