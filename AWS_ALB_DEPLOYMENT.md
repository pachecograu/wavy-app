# 🌊 WAVY - Estado real de despliegue en AWS

Inventario verificado directamente en AWS (cuenta `372714114281`, región `us-east-1`).

## ✅ Recursos activos (funcionando)

### Ingreso
- **ALB**: `wavy-alb`
- **DNS**: `wavy-alb-1189004548.us-east-1.elb.amazonaws.com`
- **Tipo**: Application Load Balancer (internet-facing)
- **Listeners**:
  - `80/HTTP` → redirección `301` a `443/HTTPS`
  - `443/HTTPS` → forward a target group `wavy-tg`
- **Certificado ACM en uso**:
  - `arn:aws:acm:us-east-1:372714114281:certificate/961d6200-5be4-406c-bc6c-8b56e7e83d11`

### Cómputo (backend)
- **ECS Cluster**: `wavy-cluster`
- **ECS Service**: `wavy-service`
- **Launch Type**: `FARGATE`
- **Task Definition activa**: `wavy-backend:1`
- **Desired / Running**: `1 / 1`
- **Container**: `wavy-backend` en puerto `3000`

### Balanceo interno
- **Target Group**: `wavy-tg`
- **Protocolo/Puerto**: `HTTP:3000`
- **Health check**: `GET /health`
- **Estado**: target saludable (`healthy`)

### Red
- **VPC**: `vpc-0481f24e860e8f51b` (default, `172.31.0.0/16`)
- **Subnets usadas por ALB**: 6 subnets default en `us-east-1a..f`
- **Subnet usada por ECS service**: `subnet-0c1dee92ffcb43f70`
- **Internet Gateway**: `igw-082b0dcd7087a5997`
- **Route table principal**: salida `0.0.0.0/0` a IGW
- **NAT Gateways**: none

### Seguridad
- **ALB SG**: `sg-016caace3ae9a1562` (`wavy-alb-sg`) abre `80/443` y `3000`
- **ECS SG**: `sg-043798a2924230dbb` (`wavy-ecs-sg`) abre `3000`, `1935`, `7880`, `8000`

### Datos y artefactos
- **S3 bucket**: `wavy-music-372714114281`
- **ECR repo**: `wavy-backend`
- **DynamoDB tables**:
  - `wavy-waves`
  - `wavy-users`
  - `wavy-tracks`
  - `wavy-backend-cache`
  - `wavy-backend-sessions`

### Logs y automatización
- **CloudWatch Log Groups**:
  - `/ecs/wavy-backend`
  - `/aws/lambda/wavy-stop-service`
- **Lambda**: `wavy-stop-service`
- **EventBridge rules**:
  - `wavy-start-service` (cron `0 13 ? * MON-FRI *`) → ejecuta ECS task en `wavy-cluster`
  - `wavy-stop-service` (cron `0 21 ? * MON-FRI *`) → invoca lambda `wavy-stop-service`

## 🌐 Endpoints de producción

- **API base (HTTPS)**: `https://wavy-alb-1189004548.us-east-1.elb.amazonaws.com`
- **Socket.IO/WSS**: `wss://wavy-alb-1189004548.us-east-1.elb.amazonaws.com`
- **Health**: `https://wavy-alb-1189004548.us-east-1.elb.amazonaws.com/health`

## 🧪 Comandos útiles (auditoría)

```bash
aws ecs describe-services --cluster wavy-cluster --services wavy-service --region us-east-1
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:us-east-1:372714114281:targetgroup/wavy-tg/2f0590ac8045354d --region us-east-1
aws logs tail /ecs/wavy-backend --follow --region us-east-1
```

## ℹ️ Notas
- No hay EC2 en ejecución para este backend.
- No hay RDS, API Gateway, CloudFront ni Route53 creados para este stack.
- El despliegue productivo actual está centrado en **ALB + ECS Fargate + DynamoDB + S3 + ECR**.
