provider "aws" {
  region = var.aws_region

  # LocalStack configuration for local development
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_region_validation      = var.use_localstack
  skip_requesting_account_id  = var.use_localstack
  s3_use_path_style           = var.use_localstack  # Required for LocalStack S3

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      ec2         = var.localstack_endpoint
      iam         = var.localstack_endpoint
      rds         = var.localstack_endpoint
      elasticache = var.localstack_endpoint
      kafka       = var.localstack_endpoint
      eks         = var.localstack_endpoint
      elb         = var.localstack_endpoint
      elbv2       = var.localstack_endpoint
      s3          = var.localstack_endpoint
      s3control   = var.localstack_endpoint
      sts         = var.localstack_endpoint
      cloudwatch  = var.localstack_endpoint
      logs        = var.localstack_endpoint
    }
  }

  default_tags {
    tags = merge(
      var.tags,
      {
        Environment = var.environment
        Project     = var.project_name
      }
    )
  }
}

