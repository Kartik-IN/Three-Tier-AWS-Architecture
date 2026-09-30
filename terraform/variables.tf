variable "aws_region" { type = string, default = "ap-south-1" }
variable "name" { type = string, default = "three-tier" }
variable "vpc_cidr" { type = string, default = "10.20.0.0/16" }
variable "availability_zones" { type = list(string), default = ["ap-south-1a", "ap-south-1b"] }
variable "public_subnet_cidrs" { type = list(string), default = ["10.20.1.0/24", "10.20.2.0/24"] }
variable "app_subnet_cidrs" { type = list(string), default = ["10.20.11.0/24", "10.20.12.0/24"] }
variable "db_subnet_cidrs" { type = list(string), default = ["10.20.21.0/24", "10.20.22.0/24"] }
variable "single_nat_gateway" { type = bool, default = true }
variable "instance_type" { type = string, default = "t3.micro" }
variable "ami_id" { type = string, default = null }
variable "app_port" { type = number, default = 8080 }
variable "asg_min_size" { type = number, default = 1 }
variable "asg_desired_capacity" { type = number, default = 2 }
variable "asg_max_size" { type = number, default = 2 }
variable "db_instance_class" { type = string, default = "db.t3.micro" }
variable "db_name" { type = string, default = "appdb" }
variable "db_username" { type = string, default = "appuser" }
variable "db_password" { type = string, sensitive = true }
variable "db_deletion_protection" { type = bool, default = false }
variable "db_backup_retention_period" { type = number, default = 1 }
variable "certificate_arn" { type = string, default = null }
variable "enable_http_redirect" { type = bool, default = true }
variable "image_uri" { type = string, default = "public.ecr.aws/docker/library/python:3.12-slim" }
