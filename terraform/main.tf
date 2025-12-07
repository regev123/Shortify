# VPC Module
module "vpc" {
  source = "./modules/vpc"

  name_prefix       = local.name_prefix
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
  use_localstack    = var.use_localstack
  tags              = local.common_tags
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security-groups"

  name_prefix    = local.name_prefix
  vpc_id         = module.vpc.vpc_id
  use_localstack = var.use_localstack
  tags           = local.common_tags
}

# RDS Module (skip for LocalStack as RDS is not supported)
module "rds" {
  count  = var.use_localstack ? 0 : 1
  source = "./modules/rds"

  name_prefix           = local.name_prefix
  db_subnet_group_name  = module.vpc.database_subnet_group_name
  security_group_ids    = [module.security_groups.rds_sg_id]
  database_name         = var.database_name
  database_username     = var.database_username
  database_password     = var.database_password
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  read_replica_count    = var.rds_read_replica_count
  skip_final_snapshot   = var.environment == "local" ? true : false
  deletion_protection   = var.environment == "prod" ? true : false
  tags                  = local.common_tags
}

# ElastiCache Module (skip for LocalStack as ElastiCache is not supported)
module "elasticache" {
  count  = var.use_localstack ? 0 : 1
  source = "./modules/elasticache"

  name_prefix          = local.name_prefix
  subnet_ids           = module.vpc.private_subnet_ids
  security_group_ids   = module.security_groups.elasticache_sg_id != null ? [module.security_groups.elasticache_sg_id] : []
  node_type            = var.elasticache_node_type
  cluster_mode_enabled = var.elasticache_cluster_mode_enabled
  num_node_groups      = var.elasticache_num_node_groups
  replicas_per_node_group = var.elasticache_replicas_per_node_group
  num_cache_nodes      = var.elasticache_num_cache_nodes
  tags                 = local.common_tags
}

# MSK Module (skip for LocalStack as MSK is not supported)
module "msk" {
  count  = var.use_localstack ? 0 : 1
  source = "./modules/msk"

  name_prefix        = local.name_prefix
  client_subnet_ids  = module.vpc.private_subnet_ids
  security_group_ids = module.security_groups.msk_sg_id != null ? [module.security_groups.msk_sg_id] : []
  broker_instance_type = var.msk_instance_type
  number_of_broker_nodes = var.msk_broker_count
  tags               = local.common_tags
}

# EKS Module (skip for LocalStack as EKS is not supported)
module "eks" {
  count  = var.use_localstack ? 0 : 1
  source = "./modules/eks"

  name_prefix    = local.name_prefix
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
  cluster_version = var.eks_cluster_version
  instance_types = var.eks_node_instance_types
  desired_size   = var.eks_node_desired_size
  min_size       = var.eks_node_min_size
  max_size       = var.eks_node_max_size
  tags           = local.common_tags
}

# ALB Module (skip for LocalStack as ELBv2 is not supported)
module "alb" {
  count  = var.use_localstack ? 0 : 1
  source = "./modules/alb"

  name_prefix        = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = module.security_groups.alb_sg_id != null ? [module.security_groups.alb_sg_id] : []
  target_port        = 8080
  health_check_path  = "/actuator/health"
  tags               = local.common_tags
}

# S3 Module
module "s3" {
  source = "./modules/s3"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

