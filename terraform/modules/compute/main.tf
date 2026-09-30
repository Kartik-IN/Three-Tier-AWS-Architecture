variable "name" { type = string }
variable "app_subnet_ids" { type = list(string) }
variable "app_security_group_id" { type = string }
variable "target_group_arn" { type = string }
variable "instance_type" { type = string }
variable "ami_id" { type = string, default = null }
variable "image_uri" { type = string }
variable "app_port" { type = number }
variable "min_size" { type = number }
variable "desired_capacity" { type = number }
variable "max_size" { type = number }
variable "database_url" { type = string, sensitive = true }
data "aws_ssm_parameter" "al2023" { name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" }
resource "aws_iam_role" "ec2" { name = "${var.name}-ec2", assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] }) }
resource "aws_iam_role_policy_attachment" "ssm" { role = aws_iam_role.ec2.name, policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" }
resource "aws_iam_instance_profile" "ec2" { name = "${var.name}-ec2", role = aws_iam_role.ec2.name }
resource "aws_launch_template" "app" { name_prefix = "${var.name}-", image_id = coalesce(var.ami_id, data.aws_ssm_parameter.al2023.value), instance_type = var.instance_type, vpc_security_group_ids = [var.app_security_group_id], iam_instance_profile { name = aws_iam_instance_profile.ec2.name }, user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", { image_uri = var.image_uri, app_port = var.app_port, database_url = var.database_url })) }
resource "aws_autoscaling_group" "app" { name = var.name, min_size = var.min_size, desired_capacity = var.desired_capacity, max_size = var.max_size, vpc_zone_identifier = var.app_subnet_ids, target_group_arns = [var.target_group_arn], health_check_type = "ELB", health_check_grace_period = 120, launch_template { id = aws_launch_template.app.id, version = "$Latest" }, instance_refresh { strategy = "Rolling", preferences { min_healthy_percentage = 50, instance_warmup = 120 } } }
