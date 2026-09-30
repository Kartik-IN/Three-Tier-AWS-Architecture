variable "name" { type = string }
variable "vpc_id" { type = string }
variable "app_port" { type = number }
resource "aws_security_group" "alb" { name = "${var.name}-alb", vpc_id = var.vpc_id, egress { protocol = "-1", from_port = 0, to_port = 0, cidr_blocks = ["0.0.0.0/0"] } }
resource "aws_vpc_security_group_ingress_rule" "alb_http" { security_group_id = aws_security_group.alb.id, cidr_ipv4 = "0.0.0.0/0", from_port = 80, to_port = 80, ip_protocol = "tcp" }
resource "aws_vpc_security_group_ingress_rule" "alb_https" { security_group_id = aws_security_group.alb.id, cidr_ipv4 = "0.0.0.0/0", from_port = 443, to_port = 443, ip_protocol = "tcp" }
resource "aws_security_group" "app" { name = "${var.name}-app", vpc_id = var.vpc_id, egress { protocol = "-1", from_port = 0, to_port = 0, cidr_blocks = ["0.0.0.0/0"] } }
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" { security_group_id = aws_security_group.app.id, referenced_security_group_id = aws_security_group.alb.id, from_port = var.app_port, to_port = var.app_port, ip_protocol = "tcp" }
resource "aws_security_group" "db" { name = "${var.name}-db", vpc_id = var.vpc_id, egress { protocol = "-1", from_port = 0, to_port = 0, cidr_blocks = ["0.0.0.0/0"] } }
resource "aws_vpc_security_group_ingress_rule" "db_from_app" { security_group_id = aws_security_group.db.id, referenced_security_group_id = aws_security_group.app.id, from_port = 5432, to_port = 5432, ip_protocol = "tcp" }
output "alb_security_group_id" { value = aws_security_group.alb.id }
output "app_security_group_id" { value = aws_security_group.app.id }
output "db_security_group_id" { value = aws_security_group.db.id }
