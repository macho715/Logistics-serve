# Terraform Variables for AWS Account 341056671376
# Samsung Logistics MCP Server

# AWS Configuration
region = "us-east-1"
environment = "prod"

# VPC Configuration (Default VPC 사용)
vpc_id = "vpc-085562473b18c7ebd"
private_subnets = ["subnet-034197c9ee667bb38", "subnet-02bcf66338191d9df"]  # 2개 AZ 서브넷
public_subnets = ["subnet-034197c9ee667bb38", "subnet-02bcf66338191d9df"]   # 2개 AZ 서브넷 (ALB용)

# ECR Image
ecr_image = "341056671376.dkr.ecr.us-east-1.amazonaws.com/samsung-logistics-mcp:latest"

# Application Configuration
cpu = 512
memory = 1024
desired_count = 2
min_capacity = 1
max_capacity = 10

# Domain Configuration (Optional)
app_domain = ""  # Leave empty if no custom domain
enable_https = false  # Set to true if you have a custom domain

# Compliance Configuration
compliance_mode = ["FANR", "MOIAT"]

# Log Configuration
log_retention_days = 30
