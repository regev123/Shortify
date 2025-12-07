# Security Group for EKS Cluster (skip for LocalStack)
resource "aws_security_group" "eks_cluster" {
  count       = var.use_localstack ? 0 : 1
  name_prefix = "${var.name_prefix}-eks-cluster-"
  vpc_id      = var.vpc_id
  description = "Security group for EKS cluster"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-eks-cluster-sg"
    }
  )
}

# Security Group for EKS Nodes (skip for LocalStack)
resource "aws_security_group" "eks_nodes" {
  count       = var.use_localstack ? 0 : 1
  name_prefix = "${var.name_prefix}-eks-nodes-"
  vpc_id      = var.vpc_id
  description = "Security group for EKS nodes"

  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-eks-nodes-sg"
    }
  )
}

# Security Group for RDS (skip for LocalStack)
resource "aws_security_group" "rds" {
  count       = var.use_localstack ? 0 : 1
  name_prefix = "${var.name_prefix}-rds-"
  vpc_id      = var.vpc_id
  description = "Security group for RDS PostgreSQL"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes[0].id]
    description     = "PostgreSQL access from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rds-sg"
    }
  )
}

# Security Group for ElastiCache (skip for LocalStack)
resource "aws_security_group" "elasticache" {
  count       = var.use_localstack ? 0 : 1
  name_prefix = "${var.name_prefix}-elasticache-"
  vpc_id      = var.vpc_id
  description = "Security group for ElastiCache Redis"

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes[0].id]
    description     = "Redis access from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-elasticache-sg"
    }
  )
}

# Security Group for MSK (skip for LocalStack)
resource "aws_security_group" "msk" {
  count       = var.use_localstack ? 0 : 1
  name_prefix = "${var.name_prefix}-msk-"
  vpc_id      = var.vpc_id
  description = "Security group for MSK Kafka"

  ingress {
    from_port       = 9092
    to_port         = 9098
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes[0].id]
    description     = "Kafka access from EKS nodes"
  }

  ingress {
    from_port       = 2181
    to_port         = 2181
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes[0].id]
    description     = "Zookeeper access from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-msk-sg"
    }
  )
}

# Security Group for ALB (skip for LocalStack)
resource "aws_security_group" "alb" {
  count       = var.use_localstack ? 0 : 1
  name_prefix = "${var.name_prefix}-alb-"
  vpc_id      = var.vpc_id
  description = "Security group for Application Load Balancer"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-alb-sg"
    }
  )
}

# Allow ALB to communicate with EKS nodes (skip for LocalStack)
resource "aws_security_group_rule" "alb_to_eks" {
  count                    = var.use_localstack ? 0 : 1
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb[0].id
  security_group_id        = aws_security_group.eks_nodes[0].id
  description              = "ALB to EKS nodes"
}

# Allow EKS cluster to communicate with nodes (skip for LocalStack)
resource "aws_security_group_rule" "eks_cluster_to_nodes" {
  count                    = var.use_localstack ? 0 : 1
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster[0].id
  security_group_id        = aws_security_group.eks_nodes[0].id
  description              = "EKS cluster to nodes"
}

