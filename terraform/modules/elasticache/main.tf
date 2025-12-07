# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.name_prefix}-elasticache-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-elasticache-subnet-group"
    }
  )
}

# ElastiCache Parameter Group (Non-Cluster Mode)
resource "aws_elasticache_parameter_group" "main" {
  count  = var.cluster_mode_enabled ? 0 : 1
  name   = "${var.name_prefix}-redis-params"
  family = var.parameter_group_family

  dynamic "parameter" {
    for_each = var.redis_parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-redis-params"
    }
  )
}

# ElastiCache Parameter Group (Cluster Mode)
resource "aws_elasticache_parameter_group" "cluster" {
  count  = var.cluster_mode_enabled ? 1 : 0
  name   = "${var.name_prefix}-redis-cluster-params"
  family = var.cluster_parameter_group_family

  dynamic "parameter" {
    for_each = var.redis_parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-redis-cluster-params"
    }
  )
}

# ElastiCache Replication Group (Cluster Mode Enabled - Redis Cluster)
# This creates a Redis cluster with multiple shards (node groups)
# Each shard can have replicas for high availability
resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "${var.name_prefix}-redis"
  description                = "Redis cluster for ${var.name_prefix} - ${var.num_node_groups} masters + ${var.replicas_per_node_group * var.num_node_groups} replicas"
  
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  port                       = 6379
  parameter_group_name       = var.cluster_mode_enabled ? aws_elasticache_parameter_group.cluster[0].name : aws_elasticache_parameter_group.main[0].name
  
  # Cluster Mode Configuration
  # Cluster mode is enabled when num_node_groups is set (and > 0)
  num_node_groups           = var.cluster_mode_enabled ? var.num_node_groups : null
  replicas_per_node_group   = var.cluster_mode_enabled ? var.replicas_per_node_group : null
  
  # Non-Cluster Mode Configuration (fallback)
  num_cache_clusters        = var.cluster_mode_enabled ? null : var.num_cache_nodes
  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled          = var.multi_az_enabled
  
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = var.security_group_ids
  
  at_rest_encryption_enabled = var.encryption_at_rest
  transit_encryption_enabled = var.encryption_in_transit
  auth_token                 = var.auth_token_enabled ? (var.auth_token != null ? var.auth_token : random_password.auth_token[0].result) : null
  
  snapshot_retention_limit   = var.snapshot_retention_limit
  snapshot_window            = var.snapshot_window
  maintenance_window         = var.maintenance_window
  
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis.name
    destination_type = "cloudwatch-logs"
    log_format       = "text"
    log_type         = "slow-log"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-redis"
    }
  )
}

# CloudWatch Log Group for Redis slow logs
resource "aws_cloudwatch_log_group" "redis" {
  name              = "/aws/elasticache/redis/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-redis-logs"
    }
  )
}

# Random password for auth token if enabled
resource "random_password" "auth_token" {
  count   = var.auth_token_enabled && var.auth_token == null ? 1 : 0
  length  = 32
  special = false
}

