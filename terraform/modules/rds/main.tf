variable "name" { type = string }
variable "db_subnet_ids" { type = list(string) }
variable "db_security_group_id" { type = string }
variable "db_name" { type = string }
variable "db_username" { type = string }
variable "db_password" { type = string, sensitive = true }
variable "instance_class" { type = string }
variable "deletion_protection" { type = bool }
variable "backup_retention_period" { type = number }
resource "aws_db_subnet_group" "this" { name = "${var.name}-db", subnet_ids = var.db_subnet_ids }
resource "aws_db_instance" "this" { identifier = "${var.name}-postgres", engine = "postgres", engine_version = "16.4", instance_class = var.instance_class, allocated_storage = 20, max_allocated_storage = 100, db_name = var.db_name, username = var.db_username, password = var.db_password, port = 5432, db_subnet_group_name = aws_db_subnet_group.this.name, vpc_security_group_ids = [var.db_security_group_id], publicly_accessible = false, storage_encrypted = true, backup_retention_period = var.backup_retention_period, deletion_protection = var.deletion_protection, skip_final_snapshot = true }
output "endpoint" { value = aws_db_instance.this.address }
