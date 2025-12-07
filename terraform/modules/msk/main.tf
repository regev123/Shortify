# MSK Configuration
resource "aws_msk_configuration" "main" {
  kafka_versions = [var.kafka_version]
  name           = "${var.name_prefix}-msk-config"

  server_properties = <<PROPERTIES
auto.create.topics.enable=true
num.network.threads=8
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
log.dirs=/tmp/kafka-logs
num.partitions=6
num.recovery.threads.per.data.dir=1
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
PROPERTIES

  description = "MSK configuration for ${var.name_prefix}"

  lifecycle {
    create_before_destroy = true
  }
}

# MSK Cluster
resource "aws_msk_cluster" "main" {
  cluster_name           = "${var.name_prefix}-kafka"
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes

  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = var.client_subnet_ids
    security_groups = var.security_group_ids

    storage_info {
      ebs_storage_info {
        provisioned_throughput {
          enabled           = false
          volume_throughput = 0
        }
        volume_size = var.broker_ebs_volume_size
      }
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.main.arn
    revision = aws_msk_configuration.main.latest_revision
  }

  encryption_info {
    encryption_in_transit {
      client_broker = var.encryption_in_transit ? "TLS" : "PLAINTEXT"
      in_cluster    = var.encryption_in_transit
    }
  }

  client_authentication {
    sasl {
      iam = var.enable_iam_auth
    }
    tls {
      certificate_authority_arns = var.certificate_authority_arns
    }
  }

  enhanced_monitoring = var.enhanced_monitoring

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = var.cloudwatch_logs_enabled
        log_group = var.cloudwatch_logs_enabled ? aws_cloudwatch_log_group.msk[0].name : null
      }
      firehose {
        enabled         = false
        delivery_stream = null
      }
      s3 {
        enabled = false
        bucket  = null
        prefix  = null
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-kafka"
    }
  )
}

# CloudWatch Log Group for MSK
resource "aws_cloudwatch_log_group" "msk" {
  count             = var.cloudwatch_logs_enabled ? 1 : 0
  name              = "/aws/msk/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-msk-logs"
    }
  )
}

