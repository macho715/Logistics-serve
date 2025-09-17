# Quick HTTPS Setup for Samsung Logistics MCP Server
# Usage: .\scripts\quick-https-setup.ps1 -Domain "mcp.your-domain.com"

param(
    [Parameter(Mandatory=$false)]
    [string]$Domain = "mcp.samsung-logistics.com"
)

Write-Host "🚀 Quick HTTPS Setup for Samsung Logistics MCP Server" -ForegroundColor Magenta
Write-Host "=====================================================" -ForegroundColor Magenta

if (-not $Domain) {
    Write-Host "❓ Enter your domain (e.g., mcp.your-domain.com):" -ForegroundColor Yellow
    $Domain = Read-Host
}

Write-Host ""
Write-Host "🎯 Setting up HTTPS for: $Domain" -ForegroundColor Green
Write-Host ""

# Check if domain is reachable
try {
    Write-Host "🔍 Checking domain availability..." -ForegroundColor Yellow
    $null = Resolve-DnsName $Domain -ErrorAction Stop
    Write-Host "✅ Domain $Domain is resolvable" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Domain $Domain is not yet resolvable (this is normal for new domains)" -ForegroundColor Yellow
    Write-Host "   Continuing with setup..." -ForegroundColor Cyan
}

# Run the main setup script
Write-Host ""
Write-Host "🔧 Starting automated HTTPS setup..." -ForegroundColor Yellow
Write-Host ""

& "$PSScriptRoot\setup-production-https.ps1" -Domain $Domain

Write-Host ""
Write-Host "🎉 Quick setup completed!" -ForegroundColor Green
Write-Host ""
Write-Host "🔧 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Verify HTTPS is working: https://$Domain/healthz" -ForegroundColor Cyan
Write-Host "2. Test SSE endpoint: https://$Domain/sse" -ForegroundColor Cyan
Write-Host "3. Register MCP connector in Claude Desktop" -ForegroundColor Cyan
Write-Host "4. Run your first logistics command!" -ForegroundColor Cyan
