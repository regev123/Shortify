variable "environment" {
  description = "Environment name (e.g., dev, staging, prod, local)"
  type        = string
  default     = "local"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "shortify"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "use_localstack" {
  description = "Whether to use LocalStack for local development"
  type        = bool
  default     = true
}

variable "localstack_endpoint" {
  description = "LocalStack endpoint URL"
  type        = string
  default     = "http://localhost:4566"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "Shortify"
    ManagedBy   = "Terraform"
    Environment = "local"
  }
}

# VPC Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# RDS Variables
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro" # Free tier compatible
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_read_replica_count" {
  description = "Number of RDS read replicas"
  type        = number
  default     = 3
}

variable "database_name" {
  description = "Database name for PRIMARY database. Read replicas automatically use the same database name. Stats DB will use: {database_name}_stats"
  type        = string
  default     = "shortifydb"
  # This creates:
  # - Primary DB: "shortifydb" (writes) → Used by Create Service
  # - Read Replicas: "shortifydb" (same name, automatically replicated from primary) → Used by Lookup Service (reads)
  # - Stats DB: "shortifydb_stats" (separate instance) → Used by Stats Service
}

variable "database_username" {
  description = "Database master username (used for all databases: primary, replicas, and stats)"
  type        = string
  default     = "shortify"
  sensitive   = true
}

variable "database_password" {
  description = "Database master password (used for all databases: primary, replicas, and stats)"
  type        = string
  default     = "ChangeMe123!"
  sensitive   = true
}

# ElastiCache Variables
variable "elasticache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro" # Free tier compatible
}

variable "elasticache_cluster_mode_enabled" {
  description = "Enable Redis cluster mode (creates 3 masters + 3 replicas = 6 nodes total)"
  type        = bool
  default     = true
  # When enabled: Creates a Redis cluster with sharding and replication
  # Matches your local Docker setup: 3 masters + 3 replicas = 6 nodes
}

variable "elasticache_num_node_groups" {
  description = "Number of node groups (shards/masters) - creates master nodes"
  type        = number
  default     = 3
  # This creates 3 master nodes (shards)
  # Each master handles a portion of the data
}

variable "elasticache_replicas_per_node_group" {
  description = "Number of replicas per node group (shard) - creates replica nodes"
  type        = number
  default     = 1
  # Creates 1 replica per master
  # Total nodes = num_node_groups * (1 + replicas_per_node_group)
  # Example: 3 masters + 3 replicas = 3 * (1 + 1) = 6 nodes total
}

variable "elasticache_num_cache_nodes" {
  description = "Number of cache nodes (for non-cluster mode only)"
  type        = number
  default     = 3
}

# MSK Variables
variable "msk_instance_type" {
  description = "MSK broker instance type"
  type        = string
  default = "kafka.t3.small" # use kafka.m5.large in production
}

variable "msk_broker_count" {
  description = "Number of MSK brokers"
  type        = number
  default     = 3
}

# EKS Variables
variable "eks_cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS nodes"
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum number of EKS nodes"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of EKS nodes"
  type        = number
  default     = 5
}

