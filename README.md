# Samsung Logistics MCP Server

Samsung C&T Logistics MCP Server for HVDC Project - ADNOC·DSV Partnership

## 🚀 Overview

This is a Model Context Protocol (MCP) server designed for Samsung C&T's logistics operations, specifically for the HVDC project in partnership with ADNOC·DSV. The server provides AI-powered logistics tools including invoice auditing, container tracking, cost calculation, and weather analysis.

## 🏗️ Architecture

- **Runtime**: Node.js 20+ with ES modules
- **Protocol**: Model Context Protocol (MCP) v0.5.0
- **Deployment**: AWS ECS Fargate with Application Load Balancer
- **Infrastructure**: Terraform-managed AWS resources
- **Containerization**: Docker with multi-stage builds
- **Monitoring**: CloudWatch with comprehensive dashboards

## 📋 Features

### Core Tools
- `health_ping` - MCP health readiness probe
- `logi_master_invoice_audit` - OCR-based invoice audit with FANR/MOIAT compliance
- `check_container_status` - ISO 6346 container tracking
- `calculate_hvdc_shipping_cost` - HVDC shipping cost calculation
- `logi_master_predict` - ETA/KPI prediction with deterministic algorithms
- `logi_master_weather_tie` - Weather-tied logistics planning

### Compliance Features
- FANR (Federal Authority for Nuclear Regulation) compliance
- MOIAT (Ministry of Industry and Advanced Technology) compliance
- GDPR data protection
- Audit trail logging
- ZERO mode fail-safe mechanisms

## 🛠️ Quick Start

### Prerequisites
- Node.js 20+
- Docker
- AWS CLI configured
- Terraform 1.6+

### Local Development

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Test health endpoint
curl http://localhost:3000/healthz
```

### Docker Build

```bash
# Build image
docker build -t samsung-logistics-mcp .

# Run container
docker run -p 3000:3000 samsung-logistics-mcp
```

## ☁️ AWS Deployment

### 1. Setup ECR Repository

```bash
# Make script executable
chmod +x scripts/setup-ecr.sh

# Setup ECR repository
./scripts/setup-ecr.sh --region me-central-1
```

### 2. Deploy Infrastructure

```bash
# Deploy with Terraform
cd terraform
terraform init
terraform plan
terraform apply
```

### 3. Deploy Application

```bash
# Deploy application (Linux/Mac)
./scripts/deploy.sh --environment prod --image-tag v1.1.0

# Deploy application (Windows)
.\scripts\deploy.ps1 -Environment prod -ImageTag v1.1.0
```

## 📊 Monitoring

### CloudWatch Dashboard
- ECS Service Metrics (CPU, Memory)
- ALB Metrics (Request Count, Response Time, Error Rates)
- Custom Logistics KPIs

### Health Checks
- Application health: `/healthz`
- MCP protocol health: Built-in MCP health checks

### Alarms
- High CPU utilization (>80%)
- High memory utilization (>85%)
- ALB 5xx errors (>10 in 5 minutes)
- ALB response time (>5 seconds)
- ECS service health (running count <1)

## 🔧 Configuration

### Environment Variables
- `PORT` - Server port (default: 3000)
- `NODE_ENV` - Environment (dev/staging/prod)
- `AWS_REGION` - AWS region
- `COMPLIANCE_MODE` - Compliance modes (FANR,MOIAT,GDPR)

### Terraform Variables
```hcl
variable "environment" {
  description = "Environment name"
  default     = "prod"
}

variable "cpu" {
  description = "CPU units for ECS task"
  default     = 512
}

variable "memory" {
  description = "Memory for ECS task in MB"
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  default     = 2
}
```

## 🔒 Security

### Encryption
- KMS encryption for CloudWatch logs
- ECR image scanning enabled
- TLS 1.3 for ALB listeners

### Network Security
- VPC with private subnets for ECS tasks
- Security groups with minimal required access
- ALB in public subnets with HTTPS redirect

### Compliance
- FANR nuclear materials compliance
- MOIAT import/export regulations
- GDPR data protection
- Audit trail for all operations

## 📈 Auto Scaling

### ECS Service Scaling
- CPU-based scaling (target: 70%)
- Memory-based scaling (target: 80%)
- ALB request count scaling (target: 1000 requests/target/5min)

### Scaling Configuration
- Min capacity: 1 task
- Max capacity: 10 tasks
- Scale-out cooldown: 5 minutes
- Scale-in cooldown: 5 minutes

## 🚨 Troubleshooting

### Common Issues

1. **Service not healthy**
   ```bash
   # Check ECS service logs
   aws logs tail /ecs/samsung-logistics-mcp --follow
   
   # Check ALB target health
   aws elbv2 describe-target-health --target-group-arn <target-group-arn>
   ```

2. **High CPU/Memory usage**
   - Check CloudWatch metrics
   - Review application logs for performance issues
   - Consider increasing task resources

3. **Deployment failures**
   - Verify ECR repository exists
   - Check AWS credentials and permissions
   - Review Terraform state for conflicts

### Logs
- Application logs: CloudWatch Log Group `/ecs/samsung-logistics-mcp`
- ALB access logs: Configure in ALB settings
- ECS service events: ECS console

## 📚 API Reference

### MCP Tools

#### health_ping
```json
{
  "name": "health_ping",
  "arguments": {
    "echo": "test message"
  }
}
```

#### logi_master_invoice_audit
```json
{
  "name": "logi_master_invoice_audit",
  "arguments": {
    "invoice_path": "AE123456.pdf"
  }
}
```

#### check_container_status
```json
{
  "name": "check_container_status",
  "arguments": {
    "container_id": "ABCD1234567"
  }
}
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

Proprietary - Samsung C&T Logistics Team

## 📞 Support

For support and questions:
- Email: logistics-team@samsung.com
- Internal Slack: #logistics-mcp-support
- Documentation: [Internal Wiki](https://wiki.samsung.com/logistics-mcp)

---

**Samsung C&T Logistics MCP Server v1.1.0**  
*HVDC Project - ADNOC·DSV Partnership*
