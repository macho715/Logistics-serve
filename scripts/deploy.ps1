# Samsung Logistics MCP Server Deployment Script (PowerShell)
# HVDC Project - Samsung C&T & ADNOC·DSV Partnership

param(
    [string]$Environment = "prod",
    [string]$ImageTag = "latest",
    [string]$AwsRegion = "me-central-1",
    [string]$EcrRepository = "123456789012.dkr.ecr.me-central-1.amazonaws.com/samsung-logistics-mcp",
    [string]$TerraformDir = "terraform"
)

# Configuration
$ErrorActionPreference = "Stop"

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
        exit 1
    }
    
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Error "Docker is required but not installed. Aborting."
        exit 1
    }
    
    if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
        Write-Error "Terraform is required but not installed. Aborting."
        exit 1
    }
    
    # Check AWS credentials
    try {
        aws sts get-caller-identity | Out-Null
    }
    catch {
        Write-Error "AWS credentials not configured. Aborting."
        exit 1
    }
    
    Write-Success "Prerequisites check passed"
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
    docker build -t "$EcrRepository`:$ImageTag" .
    
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
    
    # Test MCP tools endpoint (if available)
    $toolsUrl = "$ApplicationUrl/tools"
    try {
        $response = Invoke-WebRequest -Uri $toolsUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        Write-Success "MCP tools endpoint accessible"
    }
    catch {
        Write-Warning "MCP tools endpoint not accessible (this might be expected)"
    }
    
    Write-Success "Smoke tests completed"
}

# Main deployment function
function Start-Deployment {
    Write-Info "Starting Samsung Logistics MCP Server deployment..."
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
