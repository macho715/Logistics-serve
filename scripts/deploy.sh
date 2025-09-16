#!/bin/bash
# Samsung Logistics MCP Server Deployment Script
# HVDC Project - Samsung C&T & ADNOC·DSV Partnership

set -euo pipefail

# Configuration
AWS_REGION="${AWS_REGION:-me-central-1}"
ECR_REPOSITORY="${ECR_REPOSITORY:-123456789012.dkr.ecr.me-central-1.amazonaws.com/samsung-logistics-mcp}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
TERRAFORM_DIR="${TERRAFORM_DIR:-terraform}"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if required tools are installed
    command -v aws >/dev/null 2>&1 || { log_error "AWS CLI is required but not installed. Aborting."; exit 1; }
    command -v docker >/dev/null 2>&1 || { log_error "Docker is required but not installed. Aborting."; exit 1; }
    command -v terraform >/dev/null 2>&1 || { log_error "Terraform is required but not installed. Aborting."; exit 1; }
    
    # Check AWS credentials
    aws sts get-caller-identity >/dev/null 2>&1 || { log_error "AWS credentials not configured. Aborting."; exit 1; }
    
    log_success "Prerequisites check passed"
}

# Build and push Docker image
build_and_push_image() {
    log_info "Building and pushing Docker image..."
    
    # Login to ECR
    log_info "Logging in to Amazon ECR..."
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY
    
    # Build image
    log_info "Building Docker image..."
    docker build -t $ECR_REPOSITORY:$IMAGE_TAG .
    
    # Push image
    log_info "Pushing image to ECR..."
    docker push $ECR_REPOSITORY:$IMAGE_TAG
    
    log_success "Docker image built and pushed successfully"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    log_info "Deploying infrastructure with Terraform..."
    
    cd $TERRAFORM_DIR
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    log_info "Planning Terraform deployment..."
    terraform plan -var="ecr_image=$ECR_REPOSITORY:$IMAGE_TAG" -var="environment=$ENVIRONMENT"
    
    # Apply deployment
    log_info "Applying Terraform configuration..."
    terraform apply -auto-approve -var="ecr_image=$ECR_REPOSITORY:$IMAGE_TAG" -var="environment=$ENVIRONMENT"
    
    # Get outputs
    log_info "Getting deployment outputs..."
    ALB_DNS=$(terraform output -raw alb_dns_name)
    APPLICATION_URL=$(terraform output -raw application_url)
    HEALTH_CHECK_URL=$(terraform output -raw health_check_url)
    
    log_success "Infrastructure deployed successfully"
    log_info "ALB DNS: $ALB_DNS"
    log_info "Application URL: $APPLICATION_URL"
    log_info "Health Check URL: $HEALTH_CHECK_URL"
    
    cd ..
}

# Wait for service to be healthy
wait_for_health() {
    log_info "Waiting for service to be healthy..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$HEALTH_CHECK_URL" >/dev/null 2>&1; then
            log_success "Service is healthy!"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts: Service not ready yet, waiting 30 seconds..."
        sleep 30
        ((attempt++))
    done
    
    log_error "Service failed to become healthy after $max_attempts attempts"
    return 1
}

# Run smoke tests
run_smoke_tests() {
    log_info "Running smoke tests..."
    
    # Test health endpoint
    if curl -f -s "$HEALTH_CHECK_URL" >/dev/null 2>&1; then
        log_success "Health check passed"
    else
        log_error "Health check failed"
        return 1
    fi
    
    # Test MCP tools endpoint (if available)
    local tools_url="$APPLICATION_URL/tools"
    if curl -f -s "$tools_url" >/dev/null 2>&1; then
        log_success "MCP tools endpoint accessible"
    else
        log_warning "MCP tools endpoint not accessible (this might be expected)"
    fi
    
    log_success "Smoke tests completed"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    # Add any cleanup logic here
}

# Main deployment function
main() {
    log_info "Starting Samsung Logistics MCP Server deployment..."
    log_info "Environment: $ENVIRONMENT"
    log_info "AWS Region: $AWS_REGION"
    log_info "ECR Repository: $ECR_REPOSITORY"
    log_info "Image Tag: $IMAGE_TAG"
    
    # Set up trap for cleanup
    trap cleanup EXIT
    
    # Execute deployment steps
    check_prerequisites
    build_and_push_image
    deploy_infrastructure
    wait_for_health
    run_smoke_tests
    
    log_success "Deployment completed successfully!"
    log_info "Application URL: $APPLICATION_URL"
    log_info "Health Check URL: $HEALTH_CHECK_URL"
    log_info "CloudWatch Dashboard: https://$AWS_REGION.console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#dashboards"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --image-tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --ecr-repository)
            ECR_REPOSITORY="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --environment ENV     Environment (dev/staging/prod) [default: prod]"
            echo "  --image-tag TAG       Docker image tag [default: latest]"
            echo "  --region REGION       AWS region [default: me-central-1]"
            echo "  --ecr-repository REPO ECR repository URL"
            echo "  --help                Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main "$@"
