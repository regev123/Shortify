output "eks_cluster_sg_id" {
  description = "Security group ID for EKS cluster"
  value       = length(aws_security_group.eks_cluster) > 0 ? aws_security_group.eks_cluster[0].id : null
}

output "eks_nodes_sg_id" {
  description = "Security group ID for EKS nodes"
  value       = length(aws_security_group.eks_nodes) > 0 ? aws_security_group.eks_nodes[0].id : null
}

output "rds_sg_id" {
  description = "Security group ID for RDS"
  value       = length(aws_security_group.rds) > 0 ? aws_security_group.rds[0].id : null
}

output "elasticache_sg_id" {
  description = "Security group ID for ElastiCache"
  value       = length(aws_security_group.elasticache) > 0 ? aws_security_group.elasticache[0].id : null
}

output "msk_sg_id" {
  description = "Security group ID for MSK"
  value       = length(aws_security_group.msk) > 0 ? aws_security_group.msk[0].id : null
}

output "alb_sg_id" {
  description = "Security group ID for ALB"
  value       = length(aws_security_group.alb) > 0 ? aws_security_group.alb[0].id : null
}

