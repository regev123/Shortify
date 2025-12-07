output "rds_endpoint" {
  description = "RDS primary instance endpoint"
  value       = aws_db_instance.primary.endpoint
  sensitive   = true
}

output "rds_address" {
  description = "RDS primary instance address"
  value       = aws_db_instance.primary.address
  sensitive   = true
}

output "rds_port" {
  description = "RDS primary instance port"
  value       = aws_db_instance.primary.port
}

output "read_replica_endpoints" {
  description = "RDS read replica endpoints"
  value       = aws_db_instance.read_replicas[*].endpoint
  sensitive   = true
}

output "read_replica_addresses" {
  description = "RDS read replica addresses"
  value       = aws_db_instance.read_replicas[*].address
  sensitive   = true
}

output "rds_stats_endpoint" {
  description = "RDS stats database endpoint"
  value       = aws_db_instance.stats.endpoint
  sensitive   = true
}

output "rds_stats_address" {
  description = "RDS stats database address"
  value       = aws_db_instance.stats.address
  sensitive   = true
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.primary.db_name
}

output "database_username" {
  description = "Database username"
  value       = aws_db_instance.primary.username
  sensitive   = true
}

