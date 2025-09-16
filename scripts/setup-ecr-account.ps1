# ECR Repository Setup Script for AWS Account 341056671376
# Samsung Logistics MCP Server

param(
    [string]$AwsRegion = "me-central-1",
    [string]$RepositoryName = "samsung-logistics-mcp",
    [string]$AccountId = "341056671376"
)

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

# Check AWS CLI
function Test-AwsCli {
    Write-Info "Checking AWS CLI..."
    
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Error "AWS CLI is required but not installed. Please install AWS CLI first."
        Write-Info "Download from: https://aws.amazon.com/cli/"
        exit 1
    }
    
    # Check AWS credentials
    try {
        $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
        if ($identity.Account -ne $AccountId) {
            Write-Warning "Current AWS account ($($identity.Account)) does not match target account ($AccountId)"
            Write-Info "Please configure AWS credentials for account $AccountId"
        }
        Write-Success "AWS CLI configured for account: $($identity.Account)"
    }
    catch {
        Write-Error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    }
}

# Create ECR repository
function New-EcrRepository {
    Write-Info "Creating ECR repository: $RepositoryName"
    
    $ecrUri = "$AccountId.dkr.ecr.$AwsRegion.amazonaws.com/$RepositoryName"
    
    try {
        # Check if repository already exists
        aws ecr describe-repositories --repository-names $RepositoryName --region $AwsRegion | Out-Null
        Write-Warning "Repository $RepositoryName already exists"
    }
    catch {
        # Create repository
        Write-Info "Creating ECR repository..."
        aws ecr create-repository `
            --repository-name $RepositoryName `
            --region $AwsRegion `
            --image-scanning-configuration scanOnPush=true `
            --encryption-configuration encryptionType=AES256
        
        Write-Success "ECR repository created successfully"
    }
    
    Write-Info "ECR Repository URI: $ecrUri"
    return $ecrUri
}

# Set lifecycle policy
function Set-EcrLifecyclePolicy {
    Write-Info "Setting ECR lifecycle policy"
    
    $lifecyclePolicy = @{
        rules = @(
            @{
                rulePriority = 1
                description = "Keep last 10 production images"
                selection = @{
                    tagStatus = "tagged"
                    tagPrefixList = @("prod", "v")
                    countType = "imageCountMoreThan"
                    countNumber = 10
                }
                action = @{
                    type = "expire"
                }
            },
            @{
                rulePriority = 2
                description = "Keep last 5 staging images"
                selection = @{
                    tagStatus = "tagged"
                    tagPrefixList = @("staging", "dev")
                    countType = "imageCountMoreThan"
                    countNumber = 5
                }
                action = @{
                    type = "expire"
                }
            },
            @{
                rulePriority = 3
                description = "Delete untagged images older than 1 day"
                selection = @{
                    tagStatus = "untagged"
                    countType = "sinceImagePushed"
                    countUnit = "days"
                    countNumber = 1
                }
                action = @{
                    type = "expire"
                }
            }
        )
    }
    
    $policyJson = $lifecyclePolicy | ConvertTo-Json -Depth 10
    $policyJson | Out-File -FilePath "lifecycle-policy.json" -Encoding UTF8
    
    aws ecr put-lifecycle-policy `
        --repository-name $RepositoryName `
        --region $AwsRegion `
        --lifecycle-policy-text file://lifecycle-policy.json
    
    Remove-Item "lifecycle-policy.json" -Force
    Write-Success "ECR lifecycle policy set successfully"
}

# Main function
function Start-EcrSetup {
    Write-Info "Setting up ECR repository for Samsung Logistics MCP Server"
    Write-Info "AWS Account: $AccountId"
    Write-Info "Region: $AwsRegion"
    Write-Info "Repository: $RepositoryName"
    
    try {
        Test-AwsCli
        $ecrUri = New-EcrRepository
        Set-EcrLifecyclePolicy
        
        Write-Success "ECR repository setup completed!"
        Write-Info "Repository URI: $ecrUri"
        Write-Info "Next steps:"
        Write-Info "1. Build Docker image: docker build -t samsung-logistics-mcp ."
        Write-Info "2. Tag image: docker tag samsung-logistics-mcp:latest $ecrUri`:latest"
        Write-Info "3. Login to ECR: aws ecr get-login-password --region $AwsRegion | docker login --username AWS --password-stdin $ecrUri"
        Write-Info "4. Push image: docker push $ecrUri`:latest"
    }
    catch {
        Write-Error "ECR setup failed: $_"
        exit 1
    }
}

# Run main function
Start-EcrSetup
