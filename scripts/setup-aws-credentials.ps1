# AWS 자격 증명 설정 스크립트
# AWS 계정 341056671376 - logistics_mcp 사용자

param(
    [string]$AccessKeyId = "",
    [string]$SecretAccessKey = "",
    [string]$Region = "me-central-1"
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Set-AwsCredentials {
    Write-Info "Setting AWS credentials for account 341056671376"
    
    if ($AccessKeyId -eq "" -or $SecretAccessKey -eq "") {
        Write-Error "Access Key ID and Secret Access Key are required"
        Write-Info "Please run: .\scripts\setup-aws-credentials.ps1 -AccessKeyId 'YOUR_ACCESS_KEY' -SecretAccessKey 'YOUR_SECRET_KEY'"
        exit 1
    }
    
    # Set AWS credentials
    aws configure set aws_access_key_id $AccessKeyId
    aws configure set aws_secret_access_key $SecretAccessKey
    aws configure set default.region $Region
    aws configure set default.output json
    
    Write-Success "AWS credentials configured successfully"
}

function Test-AwsAccess {
    Write-Info "Testing AWS access..."
    
    try {
        $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
        Write-Success "AWS access verified"
        Write-Info "Account ID: $($identity.Account)"
        Write-Info "User ARN: $($identity.Arn)"
        Write-Info "Region: $Region"
        return $true
    }
    catch {
        Write-Error "AWS access test failed: $_"
        return $false
    }
}

function Start-Setup {
    Write-Info "AWS Credentials Setup for Samsung Logistics MCP Server"
    Write-Info "Account: 341056671376"
    Write-Info "User: logistics_mcp"
    Write-Info "Region: $Region"
    
    Set-AwsCredentials
    
    if (Test-AwsAccess) {
        Write-Success "AWS credentials setup completed successfully!"
        Write-Info "You can now proceed with infrastructure deployment"
    }
    else {
        Write-Error "AWS credentials setup failed"
        exit 1
    }
}

# Run setup
Start-Setup
