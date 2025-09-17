# Samsung Logistics MCP Server - HTTPS 설정 검증 스크립트
# 설정 완료 후 전체 시스템 검증

param(
    [string]$Domain = "mcp.samsung-logistics.com",
    [string]$Region = "us-east-1"
)

Write-Host "🔍 Samsung Logistics MCP HTTPS 설정 검증 시작" -ForegroundColor Green
Write-Host "Domain: $Domain" -ForegroundColor Cyan

# 검증 결과 저장
$Results = @{}

try {
    Write-Host "`n1️⃣ DNS 해석 테스트" -ForegroundColor Yellow
    $DnsResult = Resolve-DnsName -Name $Domain -Type A -ErrorAction SilentlyContinue
    if ($DnsResult) {
        Write-Host "✅ DNS 해석 성공: $($DnsResult.IPAddress -join ', ')" -ForegroundColor Green
        $Results['DNS'] = 'PASS'
    } else {
        Write-Host "❌ DNS 해석 실패" -ForegroundColor Red
        $Results['DNS'] = 'FAIL'
    }

    Write-Host "`n2️⃣ SSL/TLS 인증서 검증" -ForegroundColor Yellow
    try {
        $TcpClient = New-Object System.Net.Sockets.TcpClient
        $TcpClient.Connect($Domain, 443)
        $SslStream = New-Object System.Net.Security.SslStream($TcpClient.GetStream())
        $SslStream.AuthenticateAsClient($Domain)
        
        $Certificate = $SslStream.RemoteCertificate
        $Cert2 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($Certificate)
        
        Write-Host "✅ SSL 인증서 유효" -ForegroundColor Green
        Write-Host "   발급자: $($Cert2.Issuer)" -ForegroundColor White
        Write-Host "   유효기간: $($Cert2.NotAfter)" -ForegroundColor White
        $Results['SSL'] = 'PASS'
        
        $SslStream.Close()
        $TcpClient.Close()
    } catch {
        Write-Host "❌ SSL 인증서 검증 실패: $($_.Exception.Message)" -ForegroundColor Red
        $Results['SSL'] = 'FAIL'
    }

    Write-Host "`n3️⃣ HTTP → HTTPS 리다이렉트 테스트" -ForegroundColor Yellow
    try {
        $HttpResponse = Invoke-WebRequest -Uri "http://$Domain" -MaximumRedirection 0 -ErrorAction SilentlyContinue
    } catch {
        if ($_.Exception.Response.StatusCode -eq 301) {
            $Location = $_.Exception.Response.Headers['Location']
            if ($Location -like "https://$Domain*") {
                Write-Host "✅ HTTP → HTTPS 리다이렉트 정상 (301)" -ForegroundColor Green
                $Results['Redirect'] = 'PASS'
            } else {
                Write-Host "❌ 리다이렉트 위치 오류: $Location" -ForegroundColor Red
                $Results['Redirect'] = 'FAIL'
            }
        } else {
            Write-Host "❌ 리다이렉트 실패: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
            $Results['Redirect'] = 'FAIL'
        }
    }

    Write-Host "`n4️⃣ HTTPS 서비스 응답 테스트" -ForegroundColor Yellow
    try {
        $ServiceResponse = Invoke-WebRequest -Uri "https://$Domain/" -UseBasicParsing -TimeoutSec 10
        $ServiceInfo = $ServiceResponse.Content | ConvertFrom-Json
        
        Write-Host "✅ HTTPS 서비스 정상 응답" -ForegroundColor Green
        Write-Host "   서비스: $($ServiceInfo.service)" -ForegroundColor White
        Write-Host "   버전: $($ServiceInfo.version)" -ForegroundColor White
        Write-Host "   엔드포인트: $($ServiceInfo.endpoints | ConvertTo-Json -Compress)" -ForegroundColor White
        $Results['Service'] = 'PASS'
    } catch {
        Write-Host "❌ HTTPS 서비스 응답 실패: $($_.Exception.Message)" -ForegroundColor Red
        $Results['Service'] = 'FAIL'
    }

    Write-Host "`n5️⃣ Health Check 엔드포인트 테스트" -ForegroundColor Yellow
    try {
        $HealthResponse = Invoke-WebRequest -Uri "https://$Domain/healthz" -UseBasicParsing -TimeoutSec 10
        $HealthInfo = $HealthResponse.Content | ConvertFrom-Json
        
        if ($HealthInfo.status -eq "healthy") {
            Write-Host "✅ Health Check 정상" -ForegroundColor Green
            Write-Host "   상태: $($HealthInfo.status)" -ForegroundColor White
            Write-Host "   타임스탬프: $($HealthInfo.timestamp)" -ForegroundColor White
            $Results['Health'] = 'PASS'
        } else {
            Write-Host "❌ Health Check 비정상: $($HealthInfo.status)" -ForegroundColor Red
            $Results['Health'] = 'FAIL'
        }
    } catch {
        Write-Host "❌ Health Check 실패: $($_.Exception.Message)" -ForegroundColor Red
        $Results['Health'] = 'FAIL'
    }

    Write-Host "`n6️⃣ SSE 엔드포인트 테스트" -ForegroundColor Yellow
    try {
        # PowerShell에서 SSE는 제한적이므로 헤더만 확인
        $SSERequest = [System.Net.HttpWebRequest]::Create("https://$Domain/sse")
        $SSERequest.Method = "GET"
        $SSERequest.Accept = "text/event-stream"
        $SSERequest.Timeout = 5000
        
        $SSEResponse = $SSERequest.GetResponse()
        $ContentType = $SSEResponse.Headers["Content-Type"]
        
        if ($ContentType -eq "text/event-stream") {
            Write-Host "✅ SSE 엔드포인트 정상" -ForegroundColor Green
            Write-Host "   Content-Type: $ContentType" -ForegroundColor White
            $Results['SSE'] = 'PASS'
        } else {
            Write-Host "❌ SSE Content-Type 오류: $ContentType" -ForegroundColor Red
            $Results['SSE'] = 'FAIL'
        }
        
        $SSEResponse.Close()
    } catch {
        Write-Host "❌ SSE 엔드포인트 실패: $($_.Exception.Message)" -ForegroundColor Red
        $Results['SSE'] = 'FAIL'
    }

    Write-Host "`n7️⃣ ALB 타겟 그룹 Health Check" -ForegroundColor Yellow
    try {
        $TGHealth = aws elbv2 describe-target-health --target-group-arn $(aws elbv2 describe-target-groups --names "samsung-logistics-tg" --region $Region --query 'TargetGroups[0].TargetGroupArn' --output text) --query 'TargetHealthDescriptions[*].{Target:Target.Id,Health:TargetHealth.State}' --output json | ConvertFrom-Json
        
        $HealthyTargets = ($TGHealth | Where-Object { $_.Health -eq "healthy" }).Count
        $TotalTargets = $TGHealth.Count
        
        if ($HealthyTargets -eq $TotalTargets -and $TotalTargets -gt 0) {
            Write-Host "✅ ALB 타겟 그룹 정상: $HealthyTargets/$TotalTargets healthy" -ForegroundColor Green
            $Results['ALB_Targets'] = 'PASS'
        } else {
            Write-Host "❌ ALB 타겟 그룹 비정상: $HealthyTargets/$TotalTargets healthy" -ForegroundColor Red
            $Results['ALB_Targets'] = 'FAIL'
        }
    } catch {
        Write-Host "❌ ALB 타겟 그룹 확인 실패: $($_.Exception.Message)" -ForegroundColor Red
        $Results['ALB_Targets'] = 'FAIL'
    }

} catch {
    Write-Host "`n❌ 전체 검증 중 오류 발생: $($_.Exception.Message)" -ForegroundColor Red
}

# 결과 요약
Write-Host "`n📊 검증 결과 요약" -ForegroundColor Blue
Write-Host "=" * 50 -ForegroundColor Blue

$PassCount = ($Results.Values | Where-Object { $_ -eq 'PASS' }).Count
$TotalCount = $Results.Count

foreach ($Test in $Results.Keys | Sort-Object) {
    $Status = $Results[$Test]
    $Color = if ($Status -eq 'PASS') { 'Green' } else { 'Red' }
    $Icon = if ($Status -eq 'PASS') { '✅' } else { '❌' }
    
    Write-Host "$Icon $Test : $Status" -ForegroundColor $Color
}

Write-Host "`n🎯 전체 결과: $PassCount/$TotalCount 통과" -ForegroundColor $(if ($PassCount -eq $TotalCount) { 'Green' } else { 'Yellow' })

if ($PassCount -eq $TotalCount) {
    Write-Host "`n🎉 모든 검증 통과! MCP 커넥터 등록 준비 완료" -ForegroundColor Green
    Write-Host "MCP 커넥터 URL: https://$Domain/sse" -ForegroundColor Cyan
} else {
    Write-Host "`n⚠️  일부 검증 실패. 문제를 해결한 후 다시 시도해주세요." -ForegroundColor Yellow
}

Write-Host "`n🔧 추천 명령어:" -ForegroundColor Blue
Write-Host "/logi-master invoice-audit --mode=PRIME" -ForegroundColor White
Write-Host "/switch_mode COST-GUARD" -ForegroundColor White
Write-Host "/logi-master kpi-dash --realtime" -ForegroundColor White
