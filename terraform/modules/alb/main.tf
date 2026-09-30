variable "name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "alb_security_group_id" { type = string }
variable "app_security_group_id" { type = string }
variable "app_port" { type = number }
variable "certificate_arn" { type = string, default = null }
variable "enable_http_redirect" { type = bool }
resource "aws_lb" "this" { name = var.name, internal = false, load_balancer_type = "application", subnets = var.public_subnet_ids, security_groups = [var.alb_security_group_id], drop_invalid_header_fields = true }
resource "aws_lb_target_group" "app" { name = "${var.name}-app", port = var.app_port, protocol = "HTTP", vpc_id = var.vpc_id, target_type = "instance", health_check { path = "/health", matcher = "200", interval = 30, timeout = 5, healthy_threshold = 2, unhealthy_threshold = 3 } }
resource "aws_lb_listener" "http" { load_balancer_arn = aws_lb.this.arn, port = 80, protocol = "HTTP", default_action { type = var.certificate_arn != null && var.enable_http_redirect ? "redirect" : "forward", dynamic "redirect" { for_each = var.certificate_arn != null && var.enable_http_redirect ? [1] : [], content { port = "443", protocol = "HTTPS", status_code = "HTTP_301" } }, dynamic "forward" { for_each = var.certificate_arn != null && var.enable_http_redirect ? [] : [1], content { target_group_arn = aws_lb_target_group.app.arn } } } }
resource "aws_lb_listener" "https" { count = var.certificate_arn != null ? 1 : 0, load_balancer_arn = aws_lb.this.arn, port = 443, protocol = "HTTPS", certificate_arn = var.certificate_arn, ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06", default_action { type = "forward", forward { target_group { arn = aws_lb_target_group.app.arn, weight = 1 } } } }
output "target_group_arn" { value = aws_lb_target_group.app.arn }
output "dns_name" { value = aws_lb.this.dns_name }
