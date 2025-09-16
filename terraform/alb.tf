# Application Load Balancer for Samsung Logistics MCP Server
resource "aws_lb" "main" {
  name               = "samsung-logistics-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnets

  # Enhanced configuration for logistics workloads
  idle_timeout               = 300  # 5 minutes for long-running MCP connections
  enable_deletion_protection = var.environment == "prod" ? true : false
  enable_http2               = true
  enable_waf_fail_open      = true

  tags = {
    Name = "samsung-logistics-alb"
  }
}

# Target Group for ECS tasks
resource "aws_lb_target_group" "ecs_tasks" {
  name        = "samsung-logistics-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  # Health check configuration optimized for MCP server
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/healthz"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  # Connection draining
  deregistration_delay = 30

  tags = {
    Name = "samsung-logistics-tg"
  }
}

# HTTP Listener (redirect to HTTPS) - conditional creation
resource "aws_lb_listener" "http" {
  count             = var.enable_https && var.app_domain != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener (conditional)
resource "aws_lb_listener" "https" {
  count             = var.enable_https && var.app_domain != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.main[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tasks.arn
  }
}

# Fallback HTTP listener when HTTPS is disabled
resource "aws_lb_listener" "http_fallback" {
  count             = var.enable_https && var.app_domain != "" ? 0 : 1
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tasks.arn
  }
}
