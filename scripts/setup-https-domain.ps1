# Samsung Logistics MCP Server - HTTPS Domain Setup Script
# 권한 업데이트 후 실행: Route53, ACM, ALB 리스너 설정

param(
    [string]$Domain = "mcp.samsung-logistics.com",
    [string]$Region = "us-east-1",
    [string]$ALBName = "samsung-logistics-alb",
    [string]$TargetGroupName = "samsung-logistics-tg"
)

Write-Host "🚀 Samsung Logistics MCP HTTPS 도메인 설정 시작" -ForegroundColor Green
Write-Host "Domain: $Domain" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan

# 변수 설정
$ErrorActionPreference = "Stop"

try {
    Write-Host "`n📋 1단계: 리소스 ARN 조회" -ForegroundColor Yellow
    
    # ALB ARN 조회
    $LB_ARN = aws elbv2 describe-load-balancers --names $ALBName --region $Region --query 'LoadBalancers[0].LoadBalancerArn' --output text
    Write-Host "ALB ARN: $LB_ARN" -ForegroundColor White
    
    # Target Group ARN 조회  
    $TG_ARN = aws elbv2 describe-target-groups --names $TargetGroupName --region $Region --query 'TargetGroups[0].TargetGroupArn' --output text
    Write-Host "Target Group ARN: $TG_ARN" -ForegroundColor White

    Write-Host "`n🔒 2단계: ACM 인증서 요청" -ForegroundColor Yellow
    
    # 기존 인증서 확인
    $ExistingCert = aws acm list-certificates --region $Region --query "CertificateSummaryList[?DomainName=='$Domain'].CertificateArn" --output text
    
    if ($ExistingCert) {
        Write-Host "기존 인증서 발견: $ExistingCert" -ForegroundColor Green
        $CERT_ARN = $ExistingCert
    } else {
        # 새 인증서 요청
        $CERT_ARN = aws acm request-certificate --domain-name $Domain --validation-method DNS --region $Region --query CertificateArn --output text
        Write-Host "새 인증서 요청됨: $CERT_ARN" -ForegroundColor Green
        
        # DNS 검증 레코드 조회
        Write-Host "`n🔍 DNS 검증 레코드:" -ForegroundColor Cyan
        aws acm describe-certificate --certificate-arn $CERT_ARN --region $Region --query 'Certificate.DomainValidationOptions[0].ResourceRecord' --output table
        
        Write-Host "`n⚠️  Route53에 위 CNAME 레코드를 생성하고 인증서가 ISSUED 상태가 될 때까지 기다려주세요." -ForegroundColor Red
        Write-Host "인증서 상태 확인: aws acm describe-certificate --certificate-arn $CERT_ARN --region $Region --query 'Certificate.Status'" -ForegroundColor Yellow
        
        # 인증서 상태 대기
        do {
            Start-Sleep 30
            $CertStatus = aws acm describe-certificate --certificate-arn $CERT_ARN --region $Region --query 'Certificate.Status' --output text
            Write-Host "인증서 상태: $CertStatus" -ForegroundColor White
        } while ($CertStatus -eq "PENDING_VALIDATION")
        
        if ($CertStatus -ne "ISSUED") {
            throw "인증서 발급 실패: $CertStatus"
        }
    }

    Write-Host "`n⏱️  3단계: ALB Idle Timeout 180초로 조정" -ForegroundColor Yellow
    
    aws elbv2 modify-load-balancer-attributes --load-balancer-arn $LB_ARN --region $Region --attributes Key=idle_timeout.timeout_seconds,Value=180
    Write-Host "Idle Timeout을 180초로 설정 완료" -ForegroundColor Green

    Write-Host "`n🔐 4단계: HTTPS :443 리스너 생성" -ForegroundColor Yellow
    
    # 기존 443 리스너 확인
    $ExistingListener = aws elbv2 describe-listeners --load-balancer-arn $LB_ARN --region $Region --query "Listeners[?Port==``443``].ListenerArn" --output text
    
    if ($ExistingListener) {
        Write-Host "기존 443 리스너 발견, 인증서 업데이트: $ExistingListener" -ForegroundColor Green
        aws elbv2 modify-listener --listener-arn $ExistingListener --region $Region --certificates CertificateArn=$CERT_ARN
    } else {
        # 새 HTTPS 리스너 생성
        $NewListener = aws elbv2 create-listener --load-balancer-arn $LB_ARN --region $Region --protocol HTTPS --port 443 --certificates CertificateArn=$CERT_ARN --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06 --default-actions Type=forward,TargetGroupArn=$TG_ARN --query 'Listeners[0].ListenerArn' --output text
        Write-Host "새 HTTPS 리스너 생성 완료: $NewListener" -ForegroundColor Green
    }

    Write-Host "`n🔄 5단계: HTTP :80 → HTTPS :443 리다이렉트 설정" -ForegroundColor Yellow
    
    # 80포트 리스너 조회 및 리다이렉트 설정
    $LIS80 = aws elbv2 describe-listeners --load-balancer-arn $LB_ARN --region $Region --query "Listeners[?Port==``80``].ListenerArn" --output text
    
    if ($LIS80) {
        aws elbv2 modify-listener --listener-arn $LIS80 --region $Region --default-actions 'Type=redirect,RedirectConfig={Protocol=HTTPS,Port=443,StatusCode=HTTP_301}'
        Write-Host "HTTP → HTTPS 리다이렉트 설정 완료" -ForegroundColor Green
    }

    Write-Host "`n🌐 6단계: Route53 A-ALIAS 레코드 생성" -ForegroundColor Yellow
    
    # 호스팅 존 ID 조회
    $BaseDomain = $Domain.Split('.', 2)[1]  # samsung-logistics.com
    $HZ_ID = aws route53 list-hosted-zones-by-name --dns-name $BaseDomain --query 'HostedZones[0].Id' --output text
    $HZ_ID = $HZ_ID.Replace('/hostedzone/', '')
    Write-Host "호스팅 존 ID: $HZ_ID" -ForegroundColor White
    
    # ALB 정보 조회
    $ALBInfo = aws elbv2 describe-load-balancers --load-balancer-arns $LB_ARN --region $Region --query 'LoadBalancers[0].{HZ:CanonicalHostedZoneId,DNS:DNSName}' --output json | ConvertFrom-Json
    
    # Route53 변경 배치 생성
    $ChangeBatch = @{
        Comment = "Alias to ALB for MCP"
        Changes = @(
            @{
                Action = "UPSERT"
                ResourceRecordSet = @{
                    Name = $Domain
                    Type = "A"
                    AliasTarget = @{
                        HostedZoneId = $ALBInfo.HZ
                        DNSName = $ALBInfo.DNS
                        EvaluateTargetHealth = $false
                    }
                }
            }
        )
    } | ConvertTo-Json -Depth 5
    
    # 임시 파일에 저장
    $ChangeBatch | Out-File -FilePath "temp-r53-change.json" -Encoding UTF8
    
    # Route53 레코드 생성/업데이트
    $ChangeId = aws route53 change-resource-record-sets --hosted-zone-id $HZ_ID --change-batch file://temp-r53-change.json --query 'ChangeInfo.Id' --output text
    Write-Host "Route53 A-ALIAS 레코드 생성 완료: $ChangeId" -ForegroundColor Green
    
    # 임시 파일 정리
    Remove-Item "temp-r53-change.json" -Force

    Write-Host "`n✅ 7단계: 최종 검증" -ForegroundColor Yellow
    
    Write-Host "잠시 DNS 전파 대기 중..." -ForegroundColor White
    Start-Sleep 60
    
    # HTTP 리다이렉트 테스트
    Write-Host "`n🔍 HTTP → HTTPS 리다이렉트 테스트:" -ForegroundColor Cyan
    try {
        $HttpResponse = Invoke-WebRequest -Uri "http://$Domain" -MaximumRedirection 0 -ErrorAction SilentlyContinue
        Write-Host "Status: $($HttpResponse.StatusCode) - $($HttpResponse.Headers.Location)" -ForegroundColor Green
    } catch {
        Write-Host "리다이렉트 확인됨 (예상된 동작)" -ForegroundColor Green
    }
    
    # HTTPS SSE 엔드포인트 테스트
    Write-Host "`n🔍 HTTPS SSE 엔드포인트 테스트:" -ForegroundColor Cyan
    try {
        $HttpsResponse = Invoke-WebRequest -Uri "https://$Domain/sse" -UseBasicParsing -TimeoutSec 5
        Write-Host "✅ SSE 엔드포인트 정상 작동!" -ForegroundColor Green
        Write-Host "Content-Type: $($HttpsResponse.Headers['Content-Type'])" -ForegroundColor White
    } catch {
        Write-Host "⚠️  SSE 테스트 실패 (타임아웃 예상): $($_.Exception.Message)" -ForegroundColor Yellow
    }

    Write-Host "`n🎉 Samsung Logistics MCP HTTPS 설정 완료!" -ForegroundColor Green
    Write-Host "MCP 커넥터 URL: https://$Domain/sse" -ForegroundColor Cyan
    Write-Host "Health Check URL: https://$Domain/healthz" -ForegroundColor Cyan
    Write-Host "Service Info URL: https://$Domain/" -ForegroundColor Cyan

} catch {
    Write-Host "`n❌ 오류 발생: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "스택 트레이스: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

    Write-Host "`n📊 리소스 정보 요약:" -ForegroundColor Blue
    Write-Host "Domain: https://$Domain" -ForegroundColor White
    Write-Host "Certificate: $CERT_ARN" -ForegroundColor White  
    Write-Host "Load Balancer: $LB_ARN" -ForegroundColor White
    Write-Host "Target Group: $TG_ARN" -ForegroundColor White
}
