variable "region" {
  description = "AWS region"
  type        = string
  default     = "me-central-1"  # UAE 리전
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "VPC ID for deployment"
  type        = string
}

variable "private_subnets" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "app_domain" {
  description = "Application domain for ACM certificate (optional)"
  type        = string
  default     = ""
}

variable "ecr_image" {
  description = "ECR image URI with tag"
  type        = string
  default     = "123456789012.dkr.ecr.me-central-1.amazonaws.com/samsung-logistics-mcp:latest"
}

variable "cpu" {
  description = "CPU units for ECS task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Memory for ECS task in MB"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum capacity for auto scaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum capacity for auto scaling"
  type        = number
  default     = 10
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "enable_https" {
  description = "Enable HTTPS listener (requires valid domain)"
  type        = bool
  default     = false
}

variable "compliance_mode" {
  description = "Compliance mode (FANR/MOIAT/GDPR)"
  type        = list(string)
  default     = ["FANR", "MOIAT"]
}
