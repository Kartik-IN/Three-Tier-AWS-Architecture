variable "name" { type = string }
variable "vpc_cidr" { type = string }
variable "availability_zones" { type = list(string) }
variable "public_subnet_cidrs" { type = list(string) }
variable "app_subnet_cidrs" { type = list(string) }
variable "db_subnet_cidrs" { type = list(string) }
variable "single_nat_gateway" { type = bool }

resource "aws_vpc" "this" { cidr_block = var.vpc_cidr, enable_dns_hostnames = true, enable_dns_support = true }
resource "aws_internet_gateway" "this" { vpc_id = aws_vpc.this.id }
resource "aws_subnet" "public" { count = length(var.availability_zones), vpc_id = aws_vpc.this.id, cidr_block = var.public_subnet_cidrs[count.index], availability_zone = var.availability_zones[count.index], map_public_ip_on_launch = false }
resource "aws_subnet" "app" { count = length(var.availability_zones), vpc_id = aws_vpc.this.id, cidr_block = var.app_subnet_cidrs[count.index], availability_zone = var.availability_zones[count.index], map_public_ip_on_launch = false }
resource "aws_subnet" "db" { count = length(var.availability_zones), vpc_id = aws_vpc.this.id, cidr_block = var.db_subnet_cidrs[count.index], availability_zone = var.availability_zones[count.index], map_public_ip_on_launch = false }
resource "aws_route_table" "public" { vpc_id = aws_vpc.this.id, route { cidr_block = "0.0.0.0/0", gateway_id = aws_internet_gateway.this.id } }
resource "aws_route_table_association" "public" { count = length(aws_subnet.public), subnet_id = aws_subnet.public[count.index].id, route_table_id = aws_route_table.public.id }
resource "aws_eip" "nat" { count = var.single_nat_gateway ? 1 : length(var.availability_zones), domain = "vpc" }
resource "aws_nat_gateway" "this" { count = var.single_nat_gateway ? 1 : length(var.availability_zones), allocation_id = aws_eip.nat[count.index].id, subnet_id = aws_subnet.public[var.single_nat_gateway ? 0 : count.index].id, depends_on = [aws_internet_gateway.this] }
resource "aws_route_table" "private" { count = var.single_nat_gateway ? 1 : length(var.availability_zones), vpc_id = aws_vpc.this.id, route { cidr_block = "0.0.0.0/0", nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id } }
resource "aws_route_table_association" "app" { count = length(aws_subnet.app), subnet_id = aws_subnet.app[count.index].id, route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id }
resource "aws_route_table_association" "db" { count = length(aws_subnet.db), subnet_id = aws_subnet.db[count.index].id, route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id }
output "vpc_id" { value = aws_vpc.this.id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "app_subnet_ids" { value = aws_subnet.app[*].id }
output "db_subnet_ids" { value = aws_subnet.db[*].id }
