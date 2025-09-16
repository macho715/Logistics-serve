# Samsung Logistics MCP Server Deployment Script for AWS Account 341056671376
# HVDC Project - Samsung C&T & ADNOC·DSV Partnership

param(
    [string]$Environment = "prod",
    [string]$ImageTag = "latest",
    [string]$AwsRegion = "me-central-1",
    [string]$AccountId = "341056671376",
    [string]$TerraformDir = "terraform"
)

# Configuration
$ErrorActionPreference = "Stop"
$EcrRepository = "$AccountId.dkr.ecr.$AwsRegion.amazonaws.com/samsung-logistics-mcp"

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check prerequisites
function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check if required tools are installed
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Error "AWS CLI is required but not installed. Aborting."
        Write-Info "Download from: https://aws.amazon.com/cli/"
        exit 1
    }
    
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Error "Docker is required but not installed. Aborting."
        Write-Info "Download from: https://www.docker.com/products/docker-desktop"
        exit 1
    }
    
    if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
        Write-Error "Terraform is required but not installed. Aborting."
        Write-Info "Download from: https://www.terraform.io/downloads"
        exit 1
    }
    
    # Check AWS credentials
    try {
        $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
        if ($identity.Account -ne $AccountId) {
            Write-Warning "Current AWS account ($($identity.Account)) does not match target account ($AccountId)"
        }
        Write-Success "Prerequisites check passed"
    }
    catch {
        Write-Error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    }
}

# Build and push Docker image
function Build-AndPush-Image {
    Write-Info "Building and pushing Docker image..."
    
    # Login to ECR
    Write-Info "Logging in to Amazon ECR..."
    $ecrLogin = aws ecr get-login-password --region $AwsRegion
    $ecrLogin | docker login --username AWS --password-stdin $EcrRepository
    
    # Build image
    Write-Info "Building Docker image..."
    docker build -t samsung-logistics-mcp .
    
    # Tag image
    Write-Info "Tagging image..."
    docker tag samsung-logistics-mcp:latest "$EcrRepository`:$ImageTag"
    
    # Push image
    Write-Info "Pushing image to ECR..."
    docker push "$EcrRepository`:$ImageTag"
    
    Write-Success "Docker image built and pushed successfully"
}

# Deploy infrastructure with Terraform
function Deploy-Infrastructure {
    Write-Info "Deploying infrastructure with Terraform..."
    
    Push-Location $TerraformDir
    
    try {
        # Check if terraform.tfvars exists
        if (-not (Test-Path "terraform.tfvars")) {
            Write-Warning "terraform.tfvars not found. Please copy terraform.tfvars.example and update with your values."
            Write-Info "Required variables: vpc_id, private_subnets, public_subnets"
            exit 1
        }
        
        # Initialize Terraform
        Write-Info "Initializing Terraform..."
        terraform init
        
        # Plan deployment
        Write-Info "Planning Terraform deployment..."
        terraform plan -var="ecr_image=$EcrRepository`:$ImageTag" -var="environment=$Environment"
        
        # Apply deployment
        Write-Info "Applying Terraform configuration..."
        terraform apply -auto-approve -var="ecr_image=$EcrRepository`:$ImageTag" -var="environment=$Environment"
        
        # Get outputs
        Write-Info "Getting deployment outputs..."
        $script:AlbDns = terraform output -raw alb_dns_name
        $script:ApplicationUrl = terraform output -raw application_url
        $script:HealthCheckUrl = terraform output -raw health_check_url
        
        Write-Success "Infrastructure deployed successfully"
        Write-Info "ALB DNS: $AlbDns"
        Write-Info "Application URL: $ApplicationUrl"
        Write-Info "Health Check URL: $HealthCheckUrl"
    }
    catch {
        Write-Error "Infrastructure deployment failed: $_"
        throw
    }
    finally {
        Pop-Location
    }
}

# Wait for service to be healthy
function Wait-For-Health {
    Write-Info "Waiting for service to be healthy..."
    
    $maxAttempts = 30
    $attempt = 1
    
    while ($attempt -le $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri $HealthCheckUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Success "Service is healthy!"
                return
            }
        }
        catch {
            # Service not ready yet
        }
        
        Write-Info "Attempt $attempt/$maxAttempts : Service not ready yet, waiting 30 seconds..."
        Start-Sleep -Seconds 30
        $attempt++
    }
    
    Write-Error "Service failed to become healthy after $maxAttempts attempts"
    throw "Service health check failed"
}

# Run smoke tests
function Test-SmokeTests {
    Write-Info "Running smoke tests..."
    
    # Test health endpoint
    try {
        $response = Invoke-WebRequest -Uri $HealthCheckUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Success "Health check passed"
        }
        else {
            Write-Error "Health check failed"
            throw "Health check failed"
        }
    }
    catch {
        Write-Error "Health check failed: $_"
        throw
    }
    
    # Test root endpoint
    try {
        $response = Invoke-WebRequest -Uri $ApplicationUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        Write-Success "Application endpoint accessible"
    }
    catch {
        Write-Warning "Application endpoint not accessible: $_"
    }
    
    Write-Success "Smoke tests completed"
}

# Main deployment function
function Start-Deployment {
    Write-Info "Starting Samsung Logistics MCP Server deployment"
    Write-Info "AWS Account: $AccountId"
    Write-Info "Environment: $Environment"
    Write-Info "AWS Region: $AwsRegion"
    Write-Info "ECR Repository: $EcrRepository"
    Write-Info "Image Tag: $ImageTag"
    
    try {
        # Execute deployment steps
        Test-Prerequisites
        Build-AndPush-Image
        Deploy-Infrastructure
        Wait-For-Health
        Test-SmokeTests
        
        Write-Success "Deployment completed successfully!"
        Write-Info "Application URL: $ApplicationUrl"
        Write-Info "Health Check URL: $HealthCheckUrl"
        Write-Info "CloudWatch Dashboard: https://$AwsRegion.console.aws.amazon.com/cloudwatch/home?region=$AwsRegion#dashboards"
    }
    catch {
        Write-Error "Deployment failed: $_"
        exit 1
    }
}

# Run main function
Start-Deployment
