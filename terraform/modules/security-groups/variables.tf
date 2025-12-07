variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "use_localstack" {
  description = "Whether to use LocalStack (skip security groups for unsupported services)"
  type        = bool
  default     = false
}

