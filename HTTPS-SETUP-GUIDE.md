# Samsung Logistics MCP Server - HTTPS Setup Guide

## 🎯 Current Status

✅ **ngrok HTTPS Tunnel**: `https://97045cb6fbf5.ngrok-free.app/sse` (Working)  
✅ **AWS Infrastructure**: ALB + ECS + ECR (Deployed)  
✅ **SSE Endpoint**: Verified with proper headers and 30s+ streaming  
⏳ **Production HTTPS**: Ready for custom domain setup  

## 🌐 HTTPS Setup Options

### Option 1: Continue with ngrok (Temporary)
**Current Working Solution**
- ✅ **Immediate use**: Already configured and tested
- ✅ **Zero cost**: Free ngrok tier
- ❌ **Temporary URLs**: Changes on restart
- ❌ **Not production-ready**: Free tier limitations

**MCP Connector Settings:**
```
Name: Samsung Logistics MCP
MCP Server URL: https://97045cb6fbf5.ngrok-free.app/sse
Authentication: None
Trust: ✓ Checked
```

### Option 2: Production HTTPS with Custom Domain (Recommended)
**Permanent Solution with Fixed URL**

#### Prerequisites:
1. **Domain ownership**: You need to own a domain (e.g., `samsung-logistics.com`)
2. **DNS control**: Ability to update DNS records
3. **AWS Route53**: Recommended for automatic DNS validation

#### Quick Setup (Automated):
```powershell
# Run the automated setup script
.\scripts\quick-https-setup.ps1 -Domain "mcp.your-domain.com"
```

#### Manual Setup Steps:
1. **Create Route53 Hosted Zone** (if not exists)
2. **Request ACM Certificate** with DNS validation
3. **Create ALB HTTPS Listener** (port 443)
4. **Configure HTTP→HTTPS Redirect** (port 80)
5. **Set ALB Idle Timeout** to 180s for SSE
6. **Create Route53 A-ALIAS** record

#### After Setup:
**MCP Connector Settings:**
```
Name: Samsung Logistics MCP
MCP Server URL: https://mcp.your-domain.com/sse
Authentication: None
Trust: ✓ Checked
```

### Option 3: External DNS Provider
**Use your existing DNS provider**

#### Requirements:
- **ACM Certificate**: DNS validation via CNAME record
- **Domain CNAME**: Point `mcp.your-domain.com` to ALB DNS name
- **HTTPS Only**: ALB will handle SSL termination

#### Steps:
1. Request ACM certificate in AWS
2. Add validation CNAME to your DNS provider
3. Create ALB HTTPS listener with certificate
4. Add CNAME record: `mcp.your-domain.com` → `samsung-logistics-alb-xxx.us-east-1.elb.amazonaws.com`

## 🔧 Detailed Setup Commands

### Environment Setup:
```powershell
$REGION = "us-east-1"
$DOMAIN = "mcp.your-domain.com"  # Replace with your domain
$ALB_NAME = "samsung-logistics-alb"
$TG_NAME = "samsung-logistics-tg"
```

### 1. Get AWS Resource ARNs:
```powershell
$LB_ARN = aws elbv2 describe-load-balancers --names $ALB_NAME --region $REGION --query 'LoadBalancers[0].LoadBalancerArn' --output text
$TG_ARN = aws elbv2 describe-target-groups --names $TG_NAME --region $REGION --query 'TargetGroups[0].TargetGroupArn' --output text
```

### 2. Request ACM Certificate:
```powershell
$CERT_ARN = aws acm request-certificate --domain-name $DOMAIN --validation-method DNS --region $REGION --query CertificateArn --output text

# Get validation record
aws acm describe-certificate --certificate-arn $CERT_ARN --region $REGION --query 'Certificate.DomainValidationOptions[0].ResourceRecord'
```

### 3. Create HTTPS Listener:
```powershell
aws elbv2 create-listener --load-balancer-arn $LB_ARN --region $REGION --protocol HTTPS --port 443 --certificates CertificateArn=$CERT_ARN --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06 --default-actions Type=forward,TargetGroupArn=$TG_ARN
```

### 4. Configure HTTP Redirect:
```powershell
$HTTP_LISTENER = aws elbv2 describe-listeners --load-balancer-arn $LB_ARN --region $REGION --query 'Listeners[?Port==`80`].ListenerArn' --output text
aws elbv2 modify-listener --listener-arn $HTTP_LISTENER --region $REGION --default-actions Type=redirect,RedirectConfig='{\"Protocol\":\"HTTPS\",\"Port\":\"443\",\"StatusCode\":\"HTTP_301\"}'
```

### 5. Set ALB Timeout for SSE:
```powershell
aws elbv2 modify-load-balancer-attributes --load-balancer-arn $LB_ARN --region $REGION --attributes Key=idle_timeout.timeout_seconds,Value=180
```

## 🔍 Verification Commands

### Test Certificate:
```bash
openssl s_client -connect mcp.your-domain.com:443 -servername mcp.your-domain.com
```

### Test HTTP Redirect:
```bash
curl -I http://mcp.your-domain.com
```

### Test SSE Endpoint:
```bash
curl -N -H 'Accept: text/event-stream' https://mcp.your-domain.com/sse --max-time 30
```

### Expected Results:
```http
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache
Access-Control-Allow-Origin: *

data: {"type":"connection","timestamp":"2025-09-17T17:00:00.000Z","service":"samsung-logistics-mcp","version":"1.2.0","capabilities":["invoice-ocr","container-stowage","weather-tie","eta-prediction","compliance-check"]}
```

## 🚨 Troubleshooting

### Common Issues:

#### 1. Certificate Validation Fails
- **Cause**: DNS validation record not created or incorrect
- **Fix**: Verify CNAME record matches ACM requirements exactly
- **Check**: `dig _acme-challenge.mcp.your-domain.com CNAME`

#### 2. Domain Not Resolving
- **Cause**: DNS propagation delay or incorrect A/CNAME record
- **Fix**: Wait 5-60 minutes for DNS propagation
- **Check**: `nslookup mcp.your-domain.com`

#### 3. SSL Certificate Errors
- **Cause**: Certificate not attached to HTTPS listener
- **Fix**: Verify certificate ARN in listener configuration
- **Check**: Browser certificate details

#### 4. SSE Connection Drops
- **Cause**: ALB idle timeout too low
- **Fix**: Ensure timeout is set to 180+ seconds
- **Check**: ALB attributes in AWS console

### Support Commands:
```powershell
# Check ALB listeners
aws elbv2 describe-listeners --load-balancer-arn $LB_ARN --region $REGION

# Check certificate status
aws acm describe-certificate --certificate-arn $CERT_ARN --region $REGION

# Check Route53 records
aws route53 list-resource-record-sets --hosted-zone-id $HZ_ID
```

## 📋 Final Checklist

Before registering MCP connector:

- [ ] Domain resolves to ALB
- [ ] HTTPS certificate is valid and trusted
- [ ] HTTP redirects to HTTPS (301)
- [ ] `/healthz` returns 200 OK
- [ ] `/sse` returns `text/event-stream`
- [ ] SSE connection stays alive 30+ seconds
- [ ] ALB idle timeout is 180+ seconds

## 🎉 Success Criteria

When setup is complete, you should have:

✅ **Fixed HTTPS URL**: `https://mcp.your-domain.com/sse`  
✅ **Valid SSL Certificate**: Trusted by browsers  
✅ **Automatic HTTP Redirect**: Forces HTTPS usage  
✅ **SSE Streaming**: 30+ second connections  
✅ **Production Ready**: No ngrok dependency  

---

**Ready to register your Samsung Logistics MCP Server in Claude Desktop!** 🚢✨
