module "vpc" {
  source              = "./modules/vpc"
  name                = var.name
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  app_subnet_cidrs    = var.app_subnet_cidrs
  db_subnet_cidrs     = var.db_subnet_cidrs
  single_nat_gateway  = var.single_nat_gateway
}

module "security_groups" {
  source   = "./modules/security-groups"
  name     = var.name
  vpc_id   = module.vpc.vpc_id
  app_port = var.app_port
}

module "alb" {
  source                = "./modules/alb"
  name                  = var.name
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
  app_security_group_id = module.security_groups.app_security_group_id
  app_port              = var.app_port
  certificate_arn       = var.certificate_arn
  enable_http_redirect  = var.enable_http_redirect
}

module "compute" {
  source                = "./modules/compute"
  name                  = var.name
  app_subnet_ids        = module.vpc.app_subnet_ids
  app_security_group_id = module.security_groups.app_security_group_id
  target_group_arn      = module.alb.target_group_arn
  instance_type         = var.instance_type
  ami_id                = var.ami_id
  image_uri             = var.image_uri
  app_port              = var.app_port
  min_size              = var.asg_min_size
  desired_capacity      = var.asg_desired_capacity
  max_size              = var.asg_max_size
  database_url          = "postgresql://${var.db_username}:${var.db_password}@${module.rds.endpoint}/${var.db_name}"
  depends_on            = [module.rds]
}

module "rds" {
  source                  = "./modules/rds"
  name                    = var.name
  db_subnet_ids           = module.vpc.db_subnet_ids
  db_security_group_id    = module.security_groups.db_security_group_id
  db_name                 = var.db_name
  db_username             = var.db_username
  db_password             = var.db_password
  instance_class          = var.db_instance_class
  deletion_protection     = var.db_deletion_protection
  backup_retention_period = var.db_backup_retention_period
}
