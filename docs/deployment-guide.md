# AWS deployment guide

This guide prepares the project for deployment without applying infrastructure. Do not run `terraform apply` until the plan has been reviewed and explicitly approved.

## 1. Prerequisites

- An AWS account and a region with at least two Availability Zones.
- Terraform 1.6+ installed locally.
- AWS CLI configured with a named profile.
- Docker installed for building and publishing the application image.
- An ACM certificate in the same region as the ALB if HTTPS is required.
- A registered DNS name if the certificate will be validated through DNS.

Confirm the active identity and region:

```powershell
$env:AWS_PROFILE = "your-profile"
aws sts get-caller-identity
aws configure get region
terraform version
```

## 2. Required AWS permissions

For initial deployment, the operator or deployment role needs permissions for the following services:

- VPC: create and manage VPCs, subnets, route tables, routes, Internet Gateways, NAT Gateways, Elastic IPs, and security groups.
- EC2 and Auto Scaling: create launch templates, instance profiles, instances, target-group attachments, and Auto Scaling Groups.
- Elastic Load Balancing v2: create and manage the ALB, listeners, and target groups.
- RDS: create and manage DB subnet groups and DB instances.
- IAM: create the EC2 role and instance profile and attach `AmazonSSMManagedInstanceCore`.
- SSM: read the public Amazon Linux AMI parameter.
- CloudFormation-style tag operations where required by the selected IAM policy.

The deployment role also needs read access for Terraform refresh and delete permissions for resources it owns during teardown. Prefer a dedicated deployment role scoped to the project name and account. Do not use the account root user.

If Secrets Manager is introduced for database credentials, add narrowly scoped permissions for `secretsmanager:GetSecretValue` on the one application secret and `kms:Decrypt` only for its customer-managed KMS key.

## 3. Configuration

Create an untracked variables file:

```powershell
Copy-Item terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars` with the target region, CIDRs, capacity limits, RDS settings, and a temporary development password. Never commit this file. For production, replace the current Terraform-variable password flow with Secrets Manager before deployment.

Recommended development settings:

```hcl
single_nat_gateway          = true
instance_type               = "t3.micro"
asg_min_size                = 1
asg_desired_capacity        = 1
asg_max_size                = 2
db_instance_class           = "db.t3.micro"
db_backup_retention_period  = 1
db_deletion_protection      = false
```

For a resilient demonstration, use two NAT Gateways, at least two desired instances, a larger RDS class, longer backups, deletion protection, and an ACM certificate.

## 4. Verification before planning

Run these commands from the repository root:

```powershell
terraform -chdir=terraform fmt -recursive
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform validate
```

The current repository is not yet ready for a valid plan: Terraform reports invalid single-line blocks in the generated `.tf` files. Repair those syntax errors first. Do not proceed to `plan` until `validate` succeeds.

After validation succeeds:

```powershell
terraform -chdir=terraform plan -var-file=terraform.tfvars -out=tfplan
terraform -chdir=terraform show -no-color tfplan > plan.txt
```

Review that the plan contains no unexpected public IPs for application instances, no public RDS endpoint, only the intended ALB ingress, and the expected number of NAT Gateways. Treat `plan.txt` as sensitive because Terraform plans can contain configuration values.

Only after explicit approval:

```powershell
terraform -chdir=terraform apply tfplan
```

No `apply` command has been run for this project.

## 5. Post-deployment verification

```powershell
$alb = terraform -chdir=terraform output -raw alb_dns_name
curl.exe -i "http://$alb/health"
curl.exe -i "http://$alb/api/info"
```

Verify in the AWS console or CLI:

- ALB is internet-facing and spans two public subnets.
- Application instances have no public IPv4 addresses.
- Application instances are registered healthy in the ALB target group.
- RDS reports ` publicly_accessible = false` and uses two database subnets.
- Only the ALB security group can reach the application port.
- Only the application security group can reach TCP 5432.
- SSM can start a session to an application instance without SSH.
- The RDS endpoint is not reachable from the public internet.

## 6. Cost drivers

Costs are account- and region-dependent. This architecture is not guaranteed to be free-tier eligible. Main cost drivers are:

- Application Load Balancer hourly and capacity-unit charges.
- NAT Gateway hourly charges plus per-GB processing; NAT is usually the largest avoidable development cost.
- EC2 instance hours, EBS volumes, and data transfer.
- RDS instance hours, storage, backups, and snapshots.
- CloudWatch logs, metrics, alarms, and retention.
- ECR storage and image transfer.
- Elastic IP charges if allocated addresses remain unused.

Use one NAT Gateway and minimum capacity for development, and destroy the stack when finished. Deleting Terraform resources may not remove retained RDS snapshots, backups, CloudWatch logs, ECR images, or remote Terraform state.

## 7. Deployment checklist

- [ ] AWS identity and region confirmed.
- [ ] Terraform version meets the constraint.
- [ ] Two Availability Zones selected in the target region.
- [ ] Deployment role permissions reviewed.
- [ ] Terraform syntax repaired and `terraform validate` passes.
- [ ] Secrets are not committed or printed in logs.
- [ ] ACM certificate and DNS are ready if HTTPS is required.
- [ ] Development or demonstration capacity and cost profile selected.
- [ ] Terraform plan reviewed and saved securely.
- [ ] Public ingress is limited to the ALB.
- [ ] Application and database instances are private.
- [ ] Backup, deletion protection, and teardown decisions recorded.
- [ ] Explicit approval obtained before `terraform apply`.
- [ ] Health checks, security groups, SSM, and RDS privacy verified after deployment.
