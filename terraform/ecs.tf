# ECS Cluster for Samsung Logistics MCP Server
resource "aws_ecs_cluster" "main" {
  name = "samsung-logistics-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "samsung-logistics-cluster"
  }
}

# ECS Cluster Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# CloudWatch Log Group (KMS temporarily disabled for deployment)
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/samsung-logistics-mcp"
  retention_in_days = var.log_retention_days
  # kms_key_id        = aws_kms_key.logistics.arn  # Temporarily disabled

  tags = {
    Name = "samsung-logistics-logs"
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "samsung-logistics-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "samsung-logistics-ecs-task-execution-role"
  }
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom policy for KMS access
resource "aws_iam_role_policy" "ecs_kms_policy" {
  name = "samsung-logistics-ecs-kms-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.logistics.arn
      }
    ]
  })
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name = "samsung-logistics-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "samsung-logistics-ecs-task-role"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "samsung-logistics-mcp"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "samsung-logistics-mcp"
      image = var.ecr_image
      
      essential = true
      
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = "3000"
        },
        {
          name  = "NODE_ENV"
          value = var.environment
        },
        {
          name  = "AWS_REGION"
          value = var.region
        },
        {
          name  = "COMPLIANCE_MODE"
          value = join(",", var.compliance_mode)
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }

      # Health check
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/healthz || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      # Resource limits
      cpu    = var.cpu
      memory = var.memory
    }
  ])

  tags = {
    Name = "samsung-logistics-mcp-task"
  }
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = "samsung-logistics-mcp-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Use FARGATE_SPOT for cost optimization in non-prod
  dynamic "capacity_provider_strategy" {
    for_each = var.environment == "prod" ? [] : [1]
    content {
      capacity_provider = "FARGATE_SPOT"
      weight           = 100
      base             = 0
    }
  }

  network_configuration {
    subnets          = var.public_subnets
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tasks.arn
    container_name   = "samsung-logistics-mcp"
    container_port   = 3000
  }

  # Prevent deployment conflicts with auto scaling
  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [
    aws_lb_listener.https,
    aws_lb_listener.http_fallback,
    aws_lb_listener.http
  ]

  tags = {
    Name = "samsung-logistics-mcp-service"
  }
}
