# Security Groups for Samsung Logistics MCP Server
resource "aws_security_group" "alb" {
  name_prefix = "samsung-logistics-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from Internet (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "samsung-logistics-alb-sg"
  }
}

resource "aws_security_group" "ecs_tasks" {
  name_prefix = "samsung-logistics-ecs-"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "samsung-logistics-ecs-sg"
  }
}

# KMS Key for encryption
resource "aws_kms_key" "logistics" {
  description             = "KMS key for Samsung Logistics MCP Server"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "samsung-logistics-kms"
  }
}

resource "aws_kms_alias" "logistics" {
  name          = "alias/samsung-logistics-mcp"
  target_key_id = aws_kms_key.logistics.key_id
}
