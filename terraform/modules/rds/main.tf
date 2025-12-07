# Random password generator (if password not provided)
resource "random_password" "db_password" {
  count   = var.create_random_password ? 1 : 0
  length  = 16
  special = true
}

# DB Subnet Group (already created in VPC module, but we reference it here)
data "aws_db_subnet_group" "main" {
  name = var.db_subnet_group_name
}

# RDS Primary Instance (Write Database)
# This is the primary database for writes. Reads can be distributed to replicas.
resource "aws_db_instance" "primary" {
  identifier = "${var.name_prefix}-rds-primary"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database name for PRIMARY database (e.g., "shortifydb")
  db_name  = var.database_name
  username = var.database_username
  password = var.create_random_password ? random_password.db_password[0].result : var.database_password

  db_subnet_group_name   = data.aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = var.performance_insights_enabled

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  deletion_protection       = var.deletion_protection

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rds-primary"
      Type = "primary"
    }
  )
}

# RDS Read Replicas
# These automatically replicate from the primary database.
# They have the SAME database name as the primary (inherited automatically).
# Used for read operations to distribute load and improve performance.
resource "aws_db_instance" "read_replicas" {
  count = var.read_replica_count

  identifier = "${var.name_prefix}-rds-replica-${count.index + 1}"

  # This creates a read replica from the primary
  # The replica automatically has the SAME database name as primary
  replicate_source_db = aws_db_instance.primary.identifier
  instance_class      = var.read_replica_instance_class != null ? var.read_replica_instance_class : var.instance_class

  publicly_accessible = false
  multi_az            = false

  enabled_cloudwatch_logs_exports = ["postgresql"]
  performance_insights_enabled    = var.performance_insights_enabled

  skip_final_snapshot = true
  deletion_protection = false

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rds-replica-${count.index + 1}"
      Type = "replica"
    }
  )
}

# RDS Stats Database (Separate instance for stats service)
# This is a completely separate database instance for analytics/stats.
# It has a different database name: {database_name}_stats (e.g., "shortifydb_stats")
# This is NOT a replica - it's an independent database instance.
resource "aws_db_instance" "stats" {
  identifier = "${var.name_prefix}-rds-stats"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  # Stats database uses a different database name: {primary_name}_stats
  # Example: If primary is "shortifydb", stats will be "shortifydb_stats"
  db_name  = "${var.database_name}_stats"
  username = var.database_username
  password = var.create_random_password ? random_password.db_password[0].result : var.database_password

  db_subnet_group_name   = data.aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = var.performance_insights_enabled

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-stats-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  deletion_protection       = var.deletion_protection

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rds-stats"
      Type = "stats"
    }
  )
}
