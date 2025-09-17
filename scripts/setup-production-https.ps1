# Samsung Logistics MCP Server - Production HTTPS Setup Script
# Automates the complete setup of custom domain with ACM certificate and ALB HTTPS

param(
    [Parameter(Mandatory=$true)]
    [string]$Domain,
    
    [string]$Region = "us-east-1",
    [string]$ALBName = "samsung-logistics-alb",
    [string]$TargetGroupName = "samsung-logistics-tg"
)

# Color functions
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }
function Write-Step { param($Step, $Message) Write-Host "🔧 Step $Step`: $Message" -ForegroundColor Yellow }

Write-Host "🚀 Samsung Logistics MCP Server - Production HTTPS Setup" -ForegroundColor Magenta
Write-Host "=================================================" -ForegroundColor Magenta
Write-Info "Domain: $Domain"
Write-Info "Region: $Region"
Write-Info "ALB: $ALBName"
Write-Info "Target Group: $TargetGroupName"
Write-Host ""

# Step 0: Set AWS region
$env:AWS_DEFAULT_REGION = $Region
Write-Step "0" "Setting AWS region to $Region"

# Step 1: Get AWS resource ARNs
Write-Step "1" "Getting AWS resource information"
try {
    $LB_ARN = aws elbv2 describe-load-balancers --names $ALBName --region $Region --query 'LoadBalancers[0].LoadBalancerArn' --output text
    $TG_ARN = aws elbv2 describe-target-groups --names $TargetGroupName --region $Region --query 'TargetGroups[0].TargetGroupArn' --output text
    
    if ($LB_ARN -eq "None" -or $TG_ARN -eq "None") {
        Write-Error "ALB or Target Group not found. Please verify names."
        exit 1
    }
    
    Write-Success "Found ALB: $LB_ARN"
    Write-Success "Found Target Group: $TG_ARN"
} catch {
    Write-Error "Failed to get AWS resources: $($_.Exception.Message)"
    exit 1
}

# Step 2: Check/Create Route53 Hosted Zone
Write-Step "2" "Checking Route53 Hosted Zone"
$BaseDomain = $Domain -replace '^[^.]+\.', ''
$HZ_ID = $null

try {
    $HZ_INFO = aws route53 list-hosted-zones-by-name --dns-name $BaseDomain --query 'HostedZones[0]' --output json | ConvertFrom-Json
    
    if ($HZ_INFO.Name -eq "$BaseDomain.") {
        $HZ_ID = $HZ_INFO.Id -replace '/hostedzone/', ''
        Write-Success "Found existing hosted zone: $($HZ_INFO.Name) (ID: $HZ_ID)"
    } else {
        Write-Warning "No hosted zone found for $BaseDomain"
        $CreateHZ = Read-Host "Create hosted zone for $BaseDomain? (y/n)"
        
        if ($CreateHZ -eq 'y' -or $CreateHZ -eq 'Y') {
            $HZ_RESULT = aws route53 create-hosted-zone --name $BaseDomain --caller-reference "mcp-setup-$(Get-Date -Format 'yyyyMMdd-HHmmss')" --output json | ConvertFrom-Json
            $HZ_ID = $HZ_RESULT.HostedZone.Id -replace '/hostedzone/', ''
            Write-Success "Created hosted zone: $BaseDomain (ID: $HZ_ID)"
            Write-Warning "IMPORTANT: Update your domain registrar's NS records with these values:"
            $HZ_RESULT.DelegationSet.NameServers | ForEach-Object { Write-Info "  $_" }
            Write-Warning "Wait for DNS propagation before continuing (usually 5-60 minutes)"
            $Continue = Read-Host "Continue with certificate request? (y/n)"
            if ($Continue -ne 'y' -and $Continue -ne 'Y') {
                Write-Info "Exiting. Run this script again after DNS propagation."
                exit 0
            }
        } else {
            Write-Error "Hosted zone required for DNS validation. Exiting."
            exit 1
        }
    }
} catch {
    Write-Error "Failed to check/create hosted zone: $($_.Exception.Message)"
    exit 1
}

# Step 3: Request ACM Certificate
Write-Step "3" "Requesting ACM Certificate"
try {
    $CERT_ARN = aws acm request-certificate --domain-name $Domain --validation-method DNS --region $Region --query CertificateArn --output text
    Write-Success "Certificate requested: $CERT_ARN"
    
    # Wait a moment for validation options to be available
    Start-Sleep -Seconds 5
    
    # Get DNS validation record
    $VALIDATION = aws acm describe-certificate --certificate-arn $CERT_ARN --region $Region --query 'Certificate.DomainValidationOptions[0].ResourceRecord' --output json | ConvertFrom-Json
    
    Write-Info "DNS Validation Record:"
    Write-Info "  Name: $($VALIDATION.Name)"
    Write-Info "  Value: $($VALIDATION.Value)"
    
    # Create validation record in Route53
    $ValidationChangeSet = @{
        Comment = "ACM DNS validation for $Domain"
        Changes = @(
            @{
                Action = "UPSERT"
                ResourceRecordSet = @{
                    Name = $VALIDATION.Name
                    Type = "CNAME"
                    TTL = 300
                    ResourceRecords = @(
                        @{ Value = $VALIDATION.Value }
                    )
                }
            }
        )
    } | ConvertTo-Json -Depth 10
    
    $ValidationChangeSet | Out-File -FilePath "validation-changeset.json" -Encoding UTF8
    aws route53 change-resource-record-sets --hosted-zone-id $HZ_ID --change-batch file://validation-changeset.json
    Remove-Item "validation-changeset.json"
    
    Write-Success "DNS validation record created"
    Write-Info "Waiting for certificate validation (this may take several minutes)..."
    
    aws acm wait certificate-validated --certificate-arn $CERT_ARN --region $Region
    Write-Success "Certificate validated and issued!"
    
} catch {
    Write-Error "Failed to request/validate certificate: $($_.Exception.Message)"
    exit 1
}

# Step 4: Create HTTPS Listener
Write-Step "4" "Creating HTTPS :443 Listener"
try {
    $HTTPS_LISTENER = aws elbv2 create-listener --load-balancer-arn $LB_ARN --region $Region --protocol HTTPS --port 443 --certificates CertificateArn=$CERT_ARN --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06 --default-actions Type=forward,TargetGroupArn=$TG_ARN --query 'Listeners[0].ListenerArn' --output text
    
    Write-Success "HTTPS listener created: $HTTPS_LISTENER"
} catch {
    Write-Error "Failed to create HTTPS listener: $($_.Exception.Message)"
    exit 1
}

# Step 5: Update HTTP Listener to Redirect
Write-Step "5" "Configuring HTTP → HTTPS Redirect"
try {
    $HTTP_LISTENER = aws elbv2 describe-listeners --load-balancer-arn $LB_ARN --region $Region --query 'Listeners[?Port==`80`].ListenerArn' --output text
    
    aws elbv2 modify-listener --listener-arn $HTTP_LISTENER --region $Region --default-actions Type=redirect,RedirectConfig='{\"Protocol\":\"HTTPS\",\"Port\":\"443\",\"StatusCode\":\"HTTP_301\"}'
    
    Write-Success "HTTP listener configured for HTTPS redirect"
} catch {
    Write-Error "Failed to configure redirect: $($_.Exception.Message)"
    exit 1
}

# Step 6: Set ALB Idle Timeout for SSE
Write-Step "6" "Setting ALB Idle Timeout to 180s for SSE support"
try {
    aws elbv2 modify-load-balancer-attributes --load-balancer-arn $LB_ARN --region $Region --attributes Key=idle_timeout.timeout_seconds,Value=180
    Write-Success "ALB idle timeout set to 180 seconds"
} catch {
    Write-Error "Failed to set idle timeout: $($_.Exception.Message)"
    exit 1
}

# Step 7: Create Route53 A Record (ALIAS)
Write-Step "7" "Creating Route53 A-ALIAS record"
try {
    $ALB_INFO = aws elbv2 describe-load-balancers --load-balancer-arns $LB_ARN --region $Region --query 'LoadBalancers[0].[CanonicalHostedZoneId,DNSName]' --output text
    $ALB_HZ, $ALB_DNS = $ALB_INFO -split '\s+'
    
    $AliasChangeSet = @{
        Comment = "Alias to ALB for MCP domain $Domain"
        Changes = @(
            @{
                Action = "UPSERT"
                ResourceRecordSet = @{
                    Name = $Domain
                    Type = "A"
                    AliasTarget = @{
                        HostedZoneId = $ALB_HZ
                        DNSName = $ALB_DNS
                        EvaluateTargetHealth = $false
                    }
                }
            }
        )
    } | ConvertTo-Json -Depth 10
    
    $AliasChangeSet | Out-File -FilePath "alias-changeset.json" -Encoding UTF8
    aws route53 change-resource-record-sets --hosted-zone-id $HZ_ID --change-batch file://alias-changeset.json
    Remove-Item "alias-changeset.json"
    
    Write-Success "Route53 A-ALIAS record created: $Domain → $ALB_DNS"
} catch {
    Write-Error "Failed to create Route53 record: $($_.Exception.Message)"
    exit 1
}

# Step 8: Verification
Write-Step "8" "Verifying HTTPS Setup"
Write-Info "Waiting for DNS propagation (30 seconds)..."
Start-Sleep -Seconds 30

Write-Host ""
Write-Host "🎉 HTTPS Setup Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Success "Domain: https://$Domain"
Write-Success "MCP Server URL: https://$Domain/sse"
Write-Success "Health Check: https://$Domain/healthz"

Write-Host ""
Write-Host "🔍 Verification Commands:" -ForegroundColor Yellow
Write-Host "# Test HTTPS certificate:" -ForegroundColor Cyan
Write-Host "openssl s_client -connect $($Domain):443 -servername $Domain" -ForegroundColor Gray
Write-Host ""
Write-Host "# Test HTTP redirect:" -ForegroundColor Cyan  
Write-Host "curl -I http://$Domain" -ForegroundColor Gray
Write-Host ""
Write-Host "# Test SSE endpoint:" -ForegroundColor Cyan
Write-Host "curl -N -H 'Accept: text/event-stream' https://$Domain/sse --max-time 30" -ForegroundColor Gray

Write-Host ""
Write-Host "📋 MCP Connector Settings:" -ForegroundColor Yellow
Write-Host "Name: Samsung Logistics MCP" -ForegroundColor Cyan
Write-Host "Description: Logistics Invoice Audit & KPI Dashboard (MCP)" -ForegroundColor Cyan
Write-Host "MCP Server URL: https://$Domain/sse" -ForegroundColor Green
Write-Host "Authentication: None" -ForegroundColor Cyan
Write-Host "Trust: ✓ Checked" -ForegroundColor Cyan

Write-Host ""
Write-Success "Setup completed successfully! 🚀"
