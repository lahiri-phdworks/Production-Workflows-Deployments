# FastAPI on EC2 behind ALB with GitHub Actions + Terraform

This folder provisions:

- ALB (HTTP->HTTPS redirect) with ACM cert and target group on port 8080
- Two Ubuntu 22.04 EC2 instances running FastAPI via systemd/user_data
- S3 bucket for public images (policy in `.bucket-policy`)
- DynamoDB table (`key1` partition, `key2_sort` sort key)
- IAM role/policy for EC2 to reach the S3 bucket and DynamoDB
- Private S3 bucket for CodeDeploy bundles + CodeDeploy app/deployment group for in-place deploys
- GitHub Actions workflow to terraform apply and deploy code via CodeDeploy

## One-time setup (order matters)

1. **Backend for Terraform state**: Create an S3 bucket + DynamoDB lock table for state. Put their names in `infra/providers.tf` backend block (bucket/key/region/dynamodb_table). Do this before `terraform init`.
2. **Copy sample vars**: `cp infra/terraform.tfvars.example infra/terraform.tfvars` and fill in:
   - `vpc_id`, `alb_subnet_ids`, `app_subnet_ids`
   - `alb_certificate_arn` (from ACM in same region)
   - `ssh_key_name`, `ssh_allowed_cidr`
   - `assets_bucket_name`, `dynamodb_table_name`, `codedeploy_bucket_name`, `app_env` secrets (.env values)
   - Optional: adjust `instance_type`, `instance_count`, `tags`
3. **Inspect bucket policy**: `.bucket-policy` allows public GET on the assets bucket. Ensure you’re OK with public reads for images.
4. **Initialize/apply locally (first time)**:
   ```bash
   cd infra
   terraform init
   terraform fmt -check && terraform validate
   terraform plan -out=tfplan
   terraform apply tfplan
   ```
   Note the outputs: ALB DNS, instance IPs, bucket name, etc.

## GitHub Actions wiring

5. **IAM role for GitHub OIDC**: Create an IAM role trusted to your repo/branch with permissions for:
   - `terraform` actions: S3 state bucket access, DynamoDB lock table, EC2/ELB/ACM/IAM/DynamoDB/S3 as defined here.
   - PassRole for the EC2 instance profile and CodeDeploy service role.
   - S3 put/get on the CodeDeploy artifact bucket.
   Save its ARN in repo secret `AWS_GITHUB_ROLE_ARN`. Save the region in `AWS_REGION`.
6. **SSH access for debugging**: Create an EC2 key pair matching `ssh_key_name` if you want manual SSH. `SSH_REMOTE_USER` in `.github/workflows/deploy.yml` is set to `ubuntu` (Ubuntu 22.04 default); change if you use another user.
7. **Private app repo**: This workflow uses the current repo contents as the deploy bundle. If your FastAPI code lives elsewhere, add a checkout step (deploy key/token) before packaging.
8. **Push to main**: On push to `main`, the workflow will `terraform apply`, grab outputs, zip the repo with `appspec.yml`/scripts, upload to the CodeDeploy S3 bucket, and trigger a CodeDeploy deployment (in-place) to the tagged EC2 instances.

## Runtime expectations

- User data sets up `/opt/fastapi-app`, writes your `.env` from `var.app_env`, installs Python/uvicorn, and creates `fastapi.service`. The systemd unit re-installs `requirements.txt` on restart if the file exists.
- The ALB serves HTTPS on 443 using your ACM cert and forwards to port `var.app_port` (default 8080) on the instances. HTTP on 80 redirects to HTTPS.
- The assets S3 bucket is force-destroy enabled for convenience; turn this off for prod.

## Common tweaks

- Swap `instance_count` or `instance_type` in `terraform.tfvars`.
- Restrict `alb_allowed_cidr` if the ALB should not be public.
- If using private subnets, ensure they have NAT access for package installs.
- Add a healthier `/health` endpoint in your FastAPI app for the target group check (path `/health`).
- For blue/green with traffic control, adjust the CodeDeploy deployment group to use the ALB target group and `WITH_TRAFFIC_CONTROL`.
