# FastAPI on EC2 behind ALB with GitHub Actions + Terraform

This folder provisions:

- ALB (HTTP->HTTPS redirect) with ACM cert and target group on port 8080
- Two Ubuntu 22.04 EC2 instances running FastAPI via systemd/user_data
- S3 bucket for public images (policy in `.bucket-policy`)
- DynamoDB table (`key1` partition, `key2_sort` sort key)
- IAM role/policy for EC2 to reach the S3 bucket and DynamoDB
- GitHub Actions workflow to terraform apply and deploy code to the instances

## One-time setup (order matters)

1. **Backend for Terraform state**: Create an S3 bucket + DynamoDB lock table for state. Put their names in `infra/providers.tf` backend block (bucket/key/region/dynamodb_table). Do this before `terraform init`.
2. **Copy sample vars**: `cp infra/terraform.tfvars.example infra/terraform.tfvars` and fill in:
   - `vpc_id`, `alb_subnet_ids`, `app_subnet_ids`
   - `alb_certificate_arn` (from ACM in same region)
   - `ssh_key_name`, `ssh_allowed_cidr`
   - `assets_bucket_name`, `dynamodb_table_name`, `app_env` secrets (.env values)
   - Optional: adjust `instance_type`, `instance_count`, `tags`
3. **Inspect bucket policy**: `.bucket-policy` allows public GET on the assets bucket. Ensure you’re OK with public reads for images.
4. **Initialize/apply locally (first time)**:

```
```
   ```bash
   cd infra
   terraform init
   terraform fmt -check && terraform validate
   terraform plan -out=tfplan
   terraform apply tfplan
   ```
   
5. Note the outputs: ALB DNS, instance IPs, bucket name, etc.

## GitHub Actions wiring

5. **IAM role for GitHub OIDC**: Create an IAM role trusted to your repo/branch with permissions for:
   - `terraform` actions: S3 state bucket access, DynamoDB lock table, EC2/ELB/ACM/IAM/DynamoDB/S3 as defined here.
   - PassRole for the EC2 instance profile.
     Save its ARN in repo secret `AWS_GITHUB_ROLE_ARN`. Save the region in `AWS_REGION`.
6. **SSH access for deploy step**: Create an EC2 key pair matching `ssh_key_name`. Add the private key to repo secret `SSH_PRIVATE_KEY`. `SSH_REMOTE_USER` in `.github/workflows/deploy.yml` is set to `ubuntu` (Ubuntu 22.04 default); change if you use another user.
7. **Private app repo**: This workflow uses the current repo contents as the deploy artifact. If your FastAPI code lives in another private repo, add a deploy key or token to check it out in a prior step (or mirror it here).
8. **Push to main**: On push to `main`, the workflow will `terraform apply`, grab instance IPs, scp the app tarball to `/opt/fastapi-app/` on each instance, and restart `fastapi.service`.

## Runtime expectations

- User data sets up `/opt/fastapi-app`, writes your `.env` from `var.app_env`, installs Python/uvicorn, and creates `fastapi.service`. The systemd unit re-installs `requirements.txt` on restart if the file exists.
- The ALB serves HTTPS on 443 using your ACM cert and forwards to port `var.app_port` (default 8080) on the instances. HTTP on 80 redirects to HTTPS.
- The assets S3 bucket is force-destroy enabled for convenience; turn this off for prod.

## Common tweaks

- Swap `instance_count` or `instance_type` in `terraform.tfvars`.
- Restrict `alb_allowed_cidr` if the ALB should not be public.
- If using private subnets, ensure they have NAT access for package installs.
- Add a healthier `/health` endpoint in your FastAPI app for the target group check (path `/health`).


## Terraform Initialize

```zsh
```
terraform init

Initializing the backend...
Initializing provider plugins...
- Reusing previous version of hashicorp/aws from the dependency lock file
- Using previously-installed hashicorp/aws v5.100.0

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```
```


```bash

terraform plan -out=tfplan -parallelism=2

data.aws_ami.linux: Reading...
data.aws_ami.linux: Read complete after 1s [id=ami-02b8269d5e85954ef]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_instance.app[0] will be created
  + resource "aws_instance" "app" {
      + ami                                  = "ami-02b8269d5e85954ef"
      + arn                                  = (known after apply)
      + associate_public_ip_address          = true
      + availability_zone                    = (known after apply)
      + cpu_core_count                       = (known after apply)
      + cpu_threads_per_core                 = (known after apply)
      + disable_api_stop                     = (known after apply)
      + disable_api_termination              = (known after apply)
      + ebs_optimized                        = (known after apply)
      + enable_primary_ipv6                  = (known after apply)
      + get_password_data                    = false
      + host_id                              = (known after apply)
      + host_resource_group_arn              = (known after apply)
      + iam_instance_profile                 = (known after apply)
      + id                                   = (known after apply)
      + instance_initiated_shutdown_behavior = (known after apply)
      + instance_lifecycle                   = (known after apply)
      + instance_state                       = (known after apply)
      + instance_type                        = "t3.micro"
      + ipv6_address_count                   = (known after apply)
      + ipv6_addresses                       = (known after apply)
      + key_name                             = "default.deployment.tasks.key"
      + monitoring                           = (known after apply)
      + outpost_arn                          = (known after apply)
      + password_data                        = (known after apply)
      + placement_group                      = (known after apply)
      + placement_partition_number           = (known after apply)
      + primary_network_interface_id         = (known after apply)
      + private_dns                          = (known after apply)
      + private_ip                           = (known after apply)
      + public_dns                           = (known after apply)
      + public_ip                            = (known after apply)
      + secondary_private_ips                = (known after apply)
      + security_groups                      = (known after apply)
      + source_dest_check                    = true
      + spot_instance_request_id             = (known after apply)
      + subnet_id                            = "subnet-0ab7f29c8bb3ddf86"
      + tags                                 = {
          + "Name" = "app-ec2-instance-0"
        }
      + tags_all                             = {
          + "Name" = "app-ec2-instance-0"
        }
      + tenancy                              = (known after apply)
      + user_data                            = "0ab3725e3d6e0c126f1e02828b9aaa70aeaa5142"
      + user_data_base64                     = (known after apply)
      + user_data_replace_on_change          = false
      + vpc_security_group_ids               = (known after apply)

      + capacity_reservation_specification (known after apply)

      + cpu_options (known after apply)

      + ebs_block_device (known after apply)

      + enclave_options (known after apply)

      + ephemeral_block_device (known after apply)

      + instance_market_options (known after apply)

      + maintenance_options (known after apply)

      + metadata_options (known after apply)

      + network_interface (known after apply)

      + private_dns_name_options (known after apply)

      + root_block_device {
          + delete_on_termination = true
          + device_name           = (known after apply)
          + encrypted             = (known after apply)
          + iops                  = (known after apply)
          + kms_key_id            = (known after apply)
          + tags_all              = (known after apply)
          + throughput            = (known after apply)
          + volume_id             = (known after apply)
          + volume_size           = 80
          + volume_type           = "gp3"
        }
    }

  # aws_instance.app[1] will be created
  + resource "aws_instance" "app" {
      + ami                                  = "ami-02b8269d5e85954ef"
      + arn                                  = (known after apply)
      + associate_public_ip_address          = true
      + availability_zone                    = (known after apply)
      + cpu_core_count                       = (known after apply)
      + cpu_threads_per_core                 = (known after apply)
      + disable_api_stop                     = (known after apply)
      + disable_api_termination              = (known after apply)
      + ebs_optimized                        = (known after apply)
      + enable_primary_ipv6                  = (known after apply)
      + get_password_data                    = false
      + host_id                              = (known after apply)
      + host_resource_group_arn              = (known after apply)
      + iam_instance_profile                 = (known after apply)
      + id                                   = (known after apply)
      + instance_initiated_shutdown_behavior = (known after apply)
      + instance_lifecycle                   = (known after apply)
      + instance_state                       = (known after apply)
      + instance_type                        = "t3.micro"
      + ipv6_address_count                   = (known after apply)
      + ipv6_addresses                       = (known after apply)
      + key_name                             = "default.deployment.tasks.key"
      + monitoring                           = (known after apply)
      + outpost_arn                          = (known after apply)
      + password_data                        = (known after apply)
      + placement_group                      = (known after apply)
      + placement_partition_number           = (known after apply)
      + primary_network_interface_id         = (known after apply)
      + private_dns                          = (known after apply)
      + private_ip                           = (known after apply)
      + public_dns                           = (known after apply)
      + public_ip                            = (known after apply)
      + secondary_private_ips                = (known after apply)
      + security_groups                      = (known after apply)
      + source_dest_check                    = true
      + spot_instance_request_id             = (known after apply)
      + subnet_id                            = "subnet-07a1008dd1976efcf"
      + tags                                 = {
          + "Name" = "app-ec2-instance-1"
        }
      + tags_all                             = {
          + "Name" = "app-ec2-instance-1"
        }
      + tenancy                              = (known after apply)
      + user_data                            = "88e1d4dce565974357da0976300c621a54223c7a"
      + user_data_base64                     = (known after apply)
      + user_data_replace_on_change          = false
      + vpc_security_group_ids               = (known after apply)

      + capacity_reservation_specification (known after apply)

      + cpu_options (known after apply)

      + ebs_block_device (known after apply)

      + enclave_options (known after apply)

      + ephemeral_block_device (known after apply)

      + instance_market_options (known after apply)

      + maintenance_options (known after apply)

      + metadata_options (known after apply)

      + network_interface (known after apply)

      + private_dns_name_options (known after apply)

      + root_block_device {
          + delete_on_termination = true
          + device_name           = (known after apply)
          + encrypted             = (known after apply)
          + iops                  = (known after apply)
          + kms_key_id            = (known after apply)
          + tags_all              = (known after apply)
          + throughput            = (known after apply)
          + volume_id             = (known after apply)
          + volume_size           = 80
          + volume_type           = "gp3"
        }
    }

  # aws_lb.app_alb will be created
  + resource "aws_lb" "app_alb" {
      + arn                                                          = (known after apply)
      + arn_suffix                                                   = (known after apply)
      + client_keep_alive                                            = 3600
      + desync_mitigation_mode                                       = "defensive"
      + dns_name                                                     = (known after apply)
      + drop_invalid_header_fields                                   = false
      + enable_deletion_protection                                   = false
      + enable_http2                                                 = true
      + enable_tls_version_and_cipher_suite_headers                  = false
      + enable_waf_fail_open                                         = false
      + enable_xff_client_port                                       = false
      + enable_zonal_shift                                           = false
      + enforce_security_group_inbound_rules_on_private_link_traffic = (known after apply)
      + id                                                           = (known after apply)
      + idle_timeout                                                 = 60
      + internal                                                     = false
      + ip_address_type                                              = (known after apply)
      + load_balancer_type                                           = "application"
      + name                                                         = "app-alb-https"
      + name_prefix                                                  = (known after apply)
      + preserve_host_header                                         = false
      + security_groups                                              = (known after apply)
      + subnets                                                      = [
          + "subnet-07a1008dd1976efcf",
          + "subnet-0ab7f29c8bb3ddf86",
        ]
      + tags                                                         = {
          + "Name" = "app-alb-https"
        }
      + tags_all                                                     = {
          + "Name" = "app-alb-https"
        }
      + vpc_id                                                       = (known after apply)
      + xff_header_processing_mode                                   = "append"
      + zone_id                                                      = (known after apply)

      + subnet_mapping (known after apply)
    }

  # aws_lb_listener.http will be created
  + resource "aws_lb_listener" "http" {
      + arn                                                                   = (known after apply)
      + id                                                                    = (known after apply)
      + load_balancer_arn                                                     = (known after apply)
      + port                                                                  = 80
      + protocol                                                              = "HTTP"
      + routing_http_request_x_amzn_mtls_clientcert_header_name               = (known after apply)
      + routing_http_request_x_amzn_mtls_clientcert_issuer_header_name        = (known after apply)
      + routing_http_request_x_amzn_mtls_clientcert_leaf_header_name          = (known after apply)
      + routing_http_request_x_amzn_mtls_clientcert_serial_number_header_name = (known after apply)
      + routing_http_request_x_amzn_mtls_clientcert_subject_header_name       = (known after apply)
      + routing_http_request_x_amzn_mtls_clientcert_validity_header_name      = (known after apply)
      + routing_http_request_x_amzn_tls_cipher_suite_header_name              = (known after apply)
      + routing_http_request_x_amzn_tls_version_header_name                   = (known after apply)
      + routing_http_response_access_control_allow_credentials_header_value   = (known after apply)
      + routing_http_response_access_control_allow_headers_header_value       = (known after apply)
      + routing_http_response_access_control_allow_methods_header_value       = (known after apply)
      + routing_http_response_access_control_allow_origin_header_value        = (known after apply)
      + routing_http_response_access_control_expose_headers_header_value      = (known after apply)
      + routing_http_response_access_control_max_age_header_value             = (known after apply)
      + routing_http_response_content_security_policy_header_value            = (known after apply)
      + routing_http_response_server_enabled                                  = (known after apply)
      + routing_http_response_strict_transport_security_header_value          = (known after apply)
      + routing_http_response_x_content_type_options_header_value             = (known after apply)
      + routing_http_response_x_frame_options_header_value                    = (known after apply)
      + ssl_policy                                                            = (known after apply)
      + tags_all                                                              = (known after apply)
      + tcp_idle_timeout_seconds                                              = (known after apply)

      + default_action {
          + order = (known after apply)
          + type  = "forward"

          + forward {
              + target_group {
                  + arn    = (known after apply)
                  + weight = 1
                }
            }
        }

      + mutual_authentication (known after apply)
    }

  # aws_lb_listener.https will be created
  + resource "aws_lb_listener" "https" {
      + arn                                                                   = (known after apply)
      + certificate_arn                                                       = "arn:aws:acm:ap-south-1:171846454697:certificate/3d4df6fa-3df6-4649-bd8f-289fb23a2f51"
      + id                                                                    = (known after apply)
      + load_balancer_arn                                                     = (known after apply)
      + port                                                                  = 443
      + protocol                                                              = "HTTPS"
      + routing_http_request_x_amzn_mtls_clientcert_header_name               = (known after apply)
      + routing_http_request_x_amzn_mtls_clientcert_issuer_header_name        = (known after apply)
      + routing_http_request_x_amzn_mtls_clientcert_leaf_header_name          = (known after apply)
      + routing_http_request_x_amzn_mtls_clientcert_serial_number_header_name = (known after apply)
      + routing_http_request_x_amzn_mtls_clientcert_subject_header_name       = (known after apply)
      + routing_http_request_x_amzn_mtls_clientcert_validity_header_name      = (known after apply)
      + routing_http_request_x_amzn_tls_cipher_suite_header_name              = (known after apply)
      + routing_http_request_x_amzn_tls_version_header_name                   = (known after apply)
      + routing_http_response_access_control_allow_credentials_header_value   = (known after apply)
      + routing_http_response_access_control_allow_headers_header_value       = (known after apply)
      + routing_http_response_access_control_allow_methods_header_value       = (known after apply)
      + routing_http_response_access_control_allow_origin_header_value        = (known after apply)
      + routing_http_response_access_control_expose_headers_header_value      = (known after apply)
      + routing_http_response_access_control_max_age_header_value             = (known after apply)
      + routing_http_response_content_security_policy_header_value            = (known after apply)
      + routing_http_response_server_enabled                                  = (known after apply)
      + routing_http_response_strict_transport_security_header_value          = (known after apply)
      + routing_http_response_x_content_type_options_header_value             = (known after apply)
      + routing_http_response_x_frame_options_header_value                    = (known after apply)
      + ssl_policy                                                            = "ELBSecurityPolicy-2016-08"
      + tags_all                                                              = (known after apply)
      + tcp_idle_timeout_seconds                                              = (known after apply)

      + default_action {
          + order = (known after apply)
          + type  = "forward"

          + forward {
              + target_group {
                  + arn    = (known after apply)
                  + weight = 1
                }
            }
        }

      + mutual_authentication (known after apply)
    }

  # aws_lb_target_group.app_tg will be created
  + resource "aws_lb_target_group" "app_tg" {
      + arn                                = (known after apply)
      + arn_suffix                         = (known after apply)
      + connection_termination             = (known after apply)
      + deregistration_delay               = "300"
      + id                                 = (known after apply)
      + ip_address_type                    = (known after apply)
      + lambda_multi_value_headers_enabled = false
      + load_balancer_arns                 = (known after apply)
      + load_balancing_algorithm_type      = (known after apply)
      + load_balancing_anomaly_mitigation  = (known after apply)
      + load_balancing_cross_zone_enabled  = (known after apply)
      + name                               = "app-tg-8080"
      + name_prefix                        = (known after apply)
      + port                               = 8080
      + preserve_client_ip                 = (known after apply)
      + protocol                           = "HTTP"
      + protocol_version                   = (known after apply)
      + proxy_protocol_v2                  = false
      + slow_start                         = 0
      + tags                               = {
          + "Name" = "app-tg-8080"
        }
      + tags_all                           = {
          + "Name" = "app-tg-8080"
        }
      + target_type                        = "instance"
      + vpc_id                             = "vpc-0c27be0f6090a4ba9"

      + health_check {
          + enabled             = true
          + healthy_threshold   = 2
          + interval            = 30
          + matcher             = "200"
          + path                = "/health"
          + port                = "traffic-port"
          + protocol            = "HTTP"
          + timeout             = 5
          + unhealthy_threshold = 2
        }

      + stickiness (known after apply)

      + target_failover (known after apply)

      + target_group_health (known after apply)

      + target_health_state (known after apply)
    }

  # aws_lb_target_group_attachment.app_tg_attachment["0"] will be created
  + resource "aws_lb_target_group_attachment" "app_tg_attachment" {
      + id               = (known after apply)
      + port             = 8080
      + target_group_arn = (known after apply)
      + target_id        = (known after apply)
    }

  # aws_lb_target_group_attachment.app_tg_attachment["1"] will be created
  + resource "aws_lb_target_group_attachment" "app_tg_attachment" {
      + id               = (known after apply)
      + port             = 8080
      + target_group_arn = (known after apply)
      + target_id        = (known after apply)
    }

  # aws_security_group.alb_sg will be created
  + resource "aws_security_group" "alb_sg" {
      + arn                    = (known after apply)
      + description            = "Allow HTTPS from the internet"
      + egress                 = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "Allow all outbound"
              + from_port        = 0
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "-1"
              + security_groups  = []
              + self             = false
              + to_port          = 0
            },
        ]
      + id                     = (known after apply)
      + ingress                = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "HTTP from anywhere"
              + from_port        = 80
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 80
            },
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "HTTPS from anywhere"
              + from_port        = 443
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 443
            },
        ]
      + name                   = "alb-https-sg"
      + name_prefix            = (known after apply)
      + owner_id               = (known after apply)
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Name" = "alb-https-sg"
        }
      + tags_all               = {
          + "Name" = "alb-https-sg"
        }
      + vpc_id                 = "vpc-0c27be0f6090a4ba9"
    }

  # aws_security_group.ec2_sg will be created
  + resource "aws_security_group" "ec2_sg" {
      + arn                    = (known after apply)
      + description            = "Allow app traffic from ALB on port 8080"
      + egress                 = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "Allow all outbound"
              + from_port        = 0
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "-1"
              + security_groups  = []
              + self             = false
              + to_port          = 0
            },
        ]
      + id                     = (known after apply)
      + ingress                = [
          + {
              + cidr_blocks      = []
              + description      = "App port from ALB"
              + from_port        = 8080
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = (known after apply)
              + self             = false
              + to_port          = 8080
            },
        ]
      + name                   = "ec2-app-8080-sg"
      + name_prefix            = (known after apply)
      + owner_id               = (known after apply)
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Name" = "ec2-app-8080-sg"
        }
      + tags_all               = {
          + "Name" = "ec2-app-8080-sg"
        }
      + vpc_id                 = "vpc-0c27be0f6090a4ba9"
    }

Plan: 10 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + alb_dns_name       = (known after apply)
  + instance_public_ip = [
      + (known after apply),
      + (known after apply),
    ]

────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Saved the plan to: tfplan

To perform exactly these actions, run the following command to apply:
    terraform apply "tfplan"
```



## Apply the terraform plan.

```zsh
terraform apply "tfplan"
```


```zsh
terraform apply "tfplan"
aws_lb_target_group.app_tg: Creating...
aws_security_group.alb_sg: Creating...
aws_lb_target_group.app_tg: Creation complete after 1s [id=arn:aws:elasticloadbalancing:ap-south-1:171846454697:targetgroup/app-tg-8080/fbe7322ebf3a3a1d]
aws_security_group.alb_sg: Creation complete after 2s [id=sg-005e51b131f94add1]
aws_security_group.ec2_sg: Creating...
aws_lb.app_alb: Creating...
aws_security_group.ec2_sg: Creation complete after 3s [id=sg-05e0e1849e3bb7489]
aws_instance.app[0]: Creating...
aws_instance.app[1]: Creating...
aws_lb.app_alb: Still creating... [00m10s elapsed]
aws_instance.app[0]: Still creating... [00m10s elapsed]
aws_instance.app[1]: Still creating... [00m10s elapsed]
aws_instance.app[0]: Creation complete after 12s [id=i-069274518029bb6a5]
aws_instance.app[1]: Creation complete after 12s [id=i-05adf0b57cd99769d]
aws_lb_target_group_attachment.app_tg_attachment["1"]: Creating...
aws_lb_target_group_attachment.app_tg_attachment["0"]: Creating...
aws_lb_target_group_attachment.app_tg_attachment["0"]: Creation complete after 0s [id=arn:aws:elasticloadbalancing:ap-south-1:171846454697:targetgroup/app-tg-8080/fbe7322ebf3a3a1d-20251214061117131900000003]
aws_lb_target_group_attachment.app_tg_attachment["1"]: Creation complete after 0s [id=arn:aws:elasticloadbalancing:ap-south-1:171846454697:targetgroup/app-tg-8080/fbe7322ebf3a3a1d-20251214061117264200000004]
aws_lb.app_alb: Still creating... [00m20s elapsed]
aws_lb.app_alb: Still creating... [00m30s elapsed]
aws_lb.app_alb: Still creating... [00m40s elapsed]
aws_lb.app_alb: Still creating... [00m50s elapsed]
aws_lb.app_alb: Still creating... [01m00s elapsed]
aws_lb.app_alb: Still creating... [01m10s elapsed]
aws_lb.app_alb: Still creating... [01m20s elapsed]
aws_lb.app_alb: Still creating... [01m30s elapsed]
aws_lb.app_alb: Still creating... [01m40s elapsed]
aws_lb.app_alb: Still creating... [01m50s elapsed]
aws_lb.app_alb: Still creating... [02m00s elapsed]
aws_lb.app_alb: Still creating... [02m10s elapsed]
aws_lb.app_alb: Still creating... [02m20s elapsed]
aws_lb.app_alb: Still creating... [02m30s elapsed]
aws_lb.app_alb: Still creating... [02m40s elapsed]
aws_lb.app_alb: Still creating... [02m50s elapsed]
aws_lb.app_alb: Still creating... [03m00s elapsed]
aws_lb.app_alb: Creation complete after 3m2s [id=arn:aws:elasticloadbalancing:ap-south-1:171846454697:loadbalancer/app/app-alb-https/b88cf6d0b2602c62]
aws_lb_listener.https: Creating...
aws_lb_listener.http: Creating...
aws_lb_listener.http: Creation complete after 0s [id=arn:aws:elasticloadbalancing:ap-south-1:171846454697:listener/app/app-alb-https/b88cf6d0b2602c62/2de84c7ad62bca38]
aws_lb_listener.https: Creation complete after 0s [id=arn:aws:elasticloadbalancing:ap-south-1:171846454697:listener/app/app-alb-https/b88cf6d0b2602c62/65c6a604562dcecb]

Apply complete! Resources: 10 added, 0 changed, 0 destroyed.

Outputs:

alb_dns_name = "app-alb-https-1587303327.ap-south-1.elb.amazonaws.com"
instance_public_ip = [
  "13.233.133.84",
  "3.110.147.223",
]
```


## Destroying created resources.

```zsh
terraform destroy

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

aws_lb_target_group_attachment.app_tg_attachment["0"]: Destroying... [id=arn:aws:elasticloadbalancing:ap-south-1:171846454697:targetgroup/app-tg-8080/fbe7322ebf3a3a1d-20251214061117131900000003]
aws_lb_target_group_attachment.app_tg_attachment["1"]: Destroying... [id=arn:aws:elasticloadbalancing:ap-south-1:171846454697:targetgroup/app-tg-8080/fbe7322ebf3a3a1d-20251214061117264200000004]
aws_lb_listener.https: Destroying... [id=arn:aws:elasticloadbalancing:ap-south-1:171846454697:listener/app/app-alb-https/b88cf6d0b2602c62/65c6a604562dcecb]
aws_lb_listener.http: Destroying... [id=arn:aws:elasticloadbalancing:ap-south-1:171846454697:listener/app/app-alb-https/b88cf6d0b2602c62/2de84c7ad62bca38]
aws_lb_target_group_attachment.app_tg_attachment["0"]: Destruction complete after 0s
aws_lb_listener.https: Destruction complete after 0s
aws_lb_target_group_attachment.app_tg_attachment["1"]: Destruction complete after 0s
aws_instance.app[1]: Destroying... [id=i-05adf0b57cd99769d]
aws_instance.app[0]: Destroying... [id=i-069274518029bb6a5]
aws_lb_listener.http: Destruction complete after 1s
aws_lb.app_alb: Destroying... [id=arn:aws:elasticloadbalancing:ap-south-1:171846454697:loadbalancer/app/app-alb-https/b88cf6d0b2602c62]
aws_lb_target_group.app_tg: Destroying... [id=arn:aws:elasticloadbalancing:ap-south-1:171846454697:targetgroup/app-tg-8080/fbe7322ebf3a3a1d]
aws_lb_target_group.app_tg: Destruction complete after 0s
aws_instance.app[1]: Still destroying... [id=i-05adf0b57cd99769d, 00m10s elapsed]
aws_instance.app[0]: Still destroying... [id=i-069274518029bb6a5, 00m10s elapsed]
aws_lb.app_alb: Still destroying... [id=arn:aws:elasticloadbalancing:ap-south-1...cer/app/app-alb-https/b88cf6d0b2602c62, 00m10s elapsed]
aws_instance.app[1]: Still destroying... [id=i-05adf0b57cd99769d, 00m20s elapsed]
aws_instance.app[0]: Still destroying... [id=i-069274518029bb6a5, 00m20s elapsed]
aws_lb.app_alb: Still destroying... [id=arn:aws:elasticloadbalancing:ap-south-1...cer/app/app-alb-https/b88cf6d0b2602c62, 00m20s elapsed]
aws_lb.app_alb: Destruction complete after 26s
aws_instance.app[0]: Still destroying... [id=i-069274518029bb6a5, 00m30s elapsed]
aws_instance.app[1]: Still destroying... [id=i-05adf0b57cd99769d, 00m30s elapsed]
aws_instance.app[0]: Still destroying... [id=i-069274518029bb6a5, 00m40s elapsed]
aws_instance.app[1]: Still destroying... [id=i-05adf0b57cd99769d, 00m40s elapsed]
aws_instance.app[1]: Still destroying... [id=i-05adf0b57cd99769d, 00m50s elapsed]
aws_instance.app[0]: Still destroying... [id=i-069274518029bb6a5, 00m50s elapsed]
aws_instance.app[1]: Still destroying... [id=i-05adf0b57cd99769d, 01m00s elapsed]
aws_instance.app[0]: Still destroying... [id=i-069274518029bb6a5, 01m00s elapsed]
aws_instance.app[0]: Destruction complete after 1m1s
aws_instance.app[1]: Destruction complete after 1m1s
aws_security_group.ec2_sg: Destroying... [id=sg-05e0e1849e3bb7489]
aws_security_group.ec2_sg: Destruction complete after 0s
aws_security_group.alb_sg: Destroying... [id=sg-005e51b131f94add1]
aws_security_group.alb_sg: Destruction complete after 1s

Destroy complete! Resources: 10 destroyed.
```

