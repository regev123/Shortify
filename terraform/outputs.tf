output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "rds_endpoint" {
  description = "RDS primary instance endpoint"
  value       = length(module.rds) > 0 ? module.rds[0].rds_endpoint : null
  sensitive   = true
}

output "rds_read_replica_endpoints" {
  description = "RDS read replica endpoints"
  value       = length(module.rds) > 0 ? module.rds[0].read_replica_endpoints : null
  sensitive   = true
}

output "elasticache_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = length(module.elasticache) > 0 ? module.elasticache[0].elasticache_endpoint : null
  sensitive   = true
}

output "elasticache_configuration_endpoint" {
  description = "ElastiCache Redis configuration endpoint (for cluster mode)"
  value       = length(module.elasticache) > 0 ? module.elasticache[0].configuration_endpoint : null
  sensitive   = true
}

output "msk_broker_endpoints" {
  description = "MSK Kafka broker endpoints"
  value       = length(module.msk) > 0 ? module.msk[0].broker_endpoints : null
  sensitive   = true
}

output "msk_zookeeper_connect_string" {
  description = "MSK Zookeeper connection string"
  value       = length(module.msk) > 0 ? module.msk[0].zookeeper_connect_string : null
  sensitive   = true
}

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = length(module.eks) > 0 ? module.eks[0].cluster_id : null
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = length(module.eks) > 0 ? module.eks[0].cluster_endpoint : null
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = length(module.eks) > 0 ? module.eks[0].cluster_security_group_id : null
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = length(module.alb) > 0 ? module.alb[0].alb_dns_name : null
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = length(module.alb) > 0 ? module.alb[0].alb_arn : null
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for artifacts"
  value       = module.s3.bucket_name
}

