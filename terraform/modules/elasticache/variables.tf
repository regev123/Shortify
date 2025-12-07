variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ElastiCache"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for ElastiCache"
  type        = list(string)
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "cluster_mode_enabled" {
  description = "Enable Redis cluster mode (3 masters + 3 replicas = 6 nodes total)"
  type        = bool
  default     = true
}

variable "num_node_groups" {
  description = "Number of node groups (shards/masters) in cluster mode"
  type        = number
  default     = 3
}

variable "replicas_per_node_group" {
  description = "Number of replica nodes per node group (shard)"
  type        = number
  default     = 1
  # Total nodes = num_node_groups * (1 + replicas_per_node_group)
  # Example: 3 masters + 3 replicas = 3 * (1 + 1) = 6 nodes
}

variable "num_cache_nodes" {
  description = "Number of cache nodes (for non-cluster mode - only used when cluster_mode_enabled = false)"
  type        = number
  default     = 3
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "parameter_group_family" {
  description = "Parameter group family (for non-cluster mode)"
  type        = string
  default     = "redis7"
}

variable "cluster_parameter_group_family" {
  description = "Parameter group family (for cluster mode)"
  type        = string
  default     = "redis7.cluster.on"
}

variable "redis_parameters" {
  description = "List of Redis parameters"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "automatic_failover_enabled" {
  description = "Enable automatic failover"
  type        = bool
  default     = true
}

variable "multi_az_enabled" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = false
}

variable "encryption_at_rest" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

variable "encryption_in_transit" {
  description = "Enable encryption in transit"
  type        = bool
  default     = false
}

variable "auth_token_enabled" {
  description = "Enable auth token"
  type        = bool
  default     = false
}

variable "auth_token" {
  description = "Auth token (if null and auth_token_enabled, will generate)"
  type        = string
  default     = null
  sensitive   = true
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 7
}

variable "snapshot_window" {
  description = "Daily time range for snapshots"
  type        = string
  default     = "03:00-05:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window"
  type        = string
  default     = "mon:05:00-mon:07:00"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

