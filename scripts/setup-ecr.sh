#!/bin/bash
# ECR Repository Setup Script for Samsung Logistics MCP Server

set -euo pipefail

# Configuration
AWS_REGION="${AWS_REGION:-me-central-1}"
REPOSITORY_NAME="${REPOSITORY_NAME:-samsung-logistics-mcp}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create ECR repository
create_ecr_repository() {
    log_info "Creating ECR repository: $REPOSITORY_NAME"
    
    # Check if repository already exists
    if aws ecr describe-repositories --repository-names $REPOSITORY_NAME --region $AWS_REGION >/dev/null 2>&1; then
        log_warning "Repository $REPOSITORY_NAME already exists"
    else
        # Create repository
        aws ecr create-repository \
            --repository-name $REPOSITORY_NAME \
            --region $AWS_REGION \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256 \
            --tags Key=Project,Value=HVDC-Logistics Key=Environment,Value=Production Key=ManagedBy,Value=Terraform
        
        log_success "ECR repository created successfully"
    fi
}

# Set lifecycle policy
set_lifecycle_policy() {
    log_info "Setting ECR lifecycle policy"
    
    cat > lifecycle-policy.json << EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 10 production images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["prod", "v"],
                "countType": "imageCountMoreThan",
                "countNumber": 10
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 2,
            "description": "Keep last 5 staging images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["staging", "dev"],
                "countType": "imageCountMoreThan",
                "countNumber": 5
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 3,
            "description": "Delete untagged images older than 1 day",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 1
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF

    aws ecr put-lifecycle-policy \
        --repository-name $REPOSITORY_NAME \
        --region $AWS_REGION \
        --lifecycle-policy-text file://lifecycle-policy.json
    
    rm lifecycle-policy.json
    log_success "ECR lifecycle policy set successfully"
}

# Set repository policy
set_repository_policy() {
    log_info "Setting ECR repository policy"
    
    cat > repository-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowPushPull",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${ACCOUNT_ID}:root"
            },
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload"
            ]
        }
    ]
}
EOF

    aws ecr set-repository-policy \
        --repository-name $REPOSITORY_NAME \
        --region $AWS_REGION \
        --policy-text file://repository-policy.json
    
    rm repository-policy.json
    log_success "ECR repository policy set successfully"
}

# Main function
main() {
    log_info "Setting up ECR repository for Samsung Logistics MCP Server"
    log_info "Account ID: $ACCOUNT_ID"
    log_info "Region: $AWS_REGION"
    log_info "Repository: $REPOSITORY_NAME"
    
    create_ecr_repository
    set_lifecycle_policy
    set_repository_policy
    
    log_success "ECR repository setup completed!"
    log_info "Repository URI: $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPOSITORY_NAME"
    log_info "You can now use this URI in your Terraform configuration"
}

# Run main function
main "$@"
