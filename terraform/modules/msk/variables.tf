variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "client_subnet_ids" {
  description = "List of subnet IDs for MSK brokers"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for MSK"
  type        = list(string)
}

variable "kafka_version" {
  description = "Kafka version"
  type        = string
  default     = "3.5.1"
}

variable "number_of_broker_nodes" {
  description = "Number of broker nodes"
  type        = number
  default     = 3
}

variable "broker_instance_type" {
  description = "EC2 instance type for Kafka brokers"
  type        = string
  default     = "kafka.t3.small"
}

variable "broker_ebs_volume_size" {
  description = "EBS volume size for each broker in GB"
  type        = number
  default     = 100
}

variable "kms_key_id" {
  description = "KMS key ID for encryption at rest"
  type        = string
  default     = null
}

variable "encryption_in_transit" {
  description = "Enable encryption in transit"
  type        = bool
  default     = false
}

variable "enable_iam_auth" {
  description = "Enable IAM authentication"
  type        = bool
  default     = false
}

variable "certificate_authority_arns" {
  description = "List of certificate authority ARNs for TLS"
  type        = list(string)
  default     = []
}

variable "enhanced_monitoring" {
  description = "Enhanced monitoring level"
  type        = string
  default     = "PER_TOPIC_PER_BROKER"
}

variable "cloudwatch_logs_enabled" {
  description = "Enable CloudWatch logs"
  type        = bool
  default     = true
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

