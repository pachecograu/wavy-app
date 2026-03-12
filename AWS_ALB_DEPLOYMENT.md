# 🌊 WAVY - AWS Deployment con Application Load Balancer

## 📡 Infraestructura AWS

### Application Load Balancer (ALB)
- **DNS**: `wavy-alb-1189004548.us-east-1.elb.amazonaws.com`
- **Tipo**: Application Load Balancer
- **Región**: us-east-1
- **Puertos**: 80 (HTTP)

### ECS Fargate
- **Cluster**: wavy-cluster
- **Service**: wavy-service
- **Task Definition**: wavy-backend:1
- **CPU**: 256 (0.25 vCPU)
- **Memory**: 512 MB

### Security Groups
- **ALB SG**: sg-016caace3ae9a1562
  - Permite tráfico HTTP (80) desde internet
  - Permite tráfico en puerto 3000 desde internet
- **ECS SG**: sg-043798a2924230dbb
  - Permite tráfico desde ALB en puerto 3000

### Target Group
- **Name**: wavy-tg
- **Protocol**: HTTP
- **Port**: 3000
- **Health Check**: /health
- **Sticky Sessions**: Habilitado (24 horas)

## 🔗 Endpoints Disponibles

### Base URL
```
http://wavy-alb-1189004548.us-east-1.elb.amazonaws.com
```

### API REST

1. **Health Check**
   ```bash
   GET /health
   ```
   Retorna el estado del servidor y servicios activos.

2. **Obtener Stream URL**
   ```bash
   GET /api/rooms/:roomId/stream
   ```
   Retorna la URL del stream HLS para una sala.

3. **Generar Token de Voz (LiveKit)**
   ```bash
   POST /api/rooms/:roomId/voice-token
   Content-Type: application/json
   
   {
     "userId": "user-id",
     "isHost": true/false
   }
   ```
   Genera un token JWT para conectarse a LiveKit.

### WebSocket (Socket.IO)
```
ws://wavy-alb-1189004548.us-east-1.elb.amazonaws.com
```
Conexión Socket.IO para comunicación en tiempo real.

## 📱 Configuración de la App Flutter

La app está configurada permanentemente para usar el ALB en AWS:

```dart
// lib/core/config/app_config.dart
static const String _productionUrl = 'http://wavy-alb-1189004548.us-east-1.elb.amazonaws.com';
static String get backendUrl => _productionUrl;
```

**Todas las pruebas se realizan contra el backend en AWS.**

## 💰 Costos AWS (Free Tier)

### Incluido en Free Tier (12 meses)
- **ALB**: 750 horas/mes gratis
- **ECS Fargate**: 20 GB-hora gratis/mes
- **Data Transfer**: 15 GB salida gratis/mes
- **CloudWatch Logs**: 5 GB gratis/mes

### Después del Free Tier
- **ALB**: ~$16/mes (fijo)
- **ECS Fargate**: ~$5/mes (8 horas/día)
- **Total estimado**: ~$21/mes

## 🚀 Comandos Útiles

### Ver estado del servicio
```bash
aws ecs describe-services \
  --cluster wavy-cluster \
  --services wavy-service \
  --region us-east-1
```

### Ver salud del Target Group
```bash
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:372714114281:targetgroup/wavy-tg/2f0590ac8045354d
```

### Ver logs del contenedor
```bash
aws logs tail /ecs/wavy-backend --follow --region us-east-1
```

### Forzar redespliegue
```bash
aws ecs update-service \
  --cluster wavy-cluster \
  --service wavy-service \
  --force-new-deployment \
  --region us-east-1
```

## 🔧 Troubleshooting

### El ALB retorna 503 Service Unavailable
- Verificar que el Target Group tenga targets "healthy"
- Revisar Security Groups (ECS debe aceptar tráfico del ALB)
- Verificar que el contenedor esté corriendo

### WebSocket no conecta
- Verificar que sticky sessions estén habilitados
- Comprobar que el puerto 3000 esté abierto en el ALB
- Revisar logs del contenedor

### Health check falla
- Verificar que el endpoint /health responda correctamente
- Comprobar que el contenedor esté escuchando en puerto 3000
- Revisar timeout del health check (5 segundos)

## 📊 Monitoreo

### CloudWatch Metrics
- ALB Request Count
- Target Response Time
- Healthy/Unhealthy Host Count
- ECS CPU/Memory Utilization

### Logs
- ALB Access Logs: Deshabilitado (para ahorrar costos)
- ECS Container Logs: `/ecs/wavy-backend`

## 🔐 Seguridad

### Recomendaciones para Producción
1. **HTTPS**: Agregar certificado SSL con AWS Certificate Manager
2. **WAF**: Considerar AWS WAF para protección adicional
3. **Secrets**: Mover credenciales a AWS Secrets Manager
4. **VPC**: Considerar usar subnets privadas para ECS

### Configuración Actual
- HTTP sin cifrado (para desarrollo)
- Subnets públicas
- Credenciales en variables de entorno

## 🎯 Próximos Pasos

1. **HTTPS**: Configurar certificado SSL gratuito
2. **Dominio**: Registrar dominio personalizado
3. **CI/CD**: Automatizar despliegues con GitHub Actions
4. **Monitoring**: Configurar alarmas en CloudWatch
5. **Backup**: Implementar respaldo de datos

## 📝 Notas

- El ALB tiene una URL fija que no cambia con redespliegues
- Sticky sessions garantizan que WebSocket funcione correctamente
- El health check se ejecuta cada 30 segundos
- El contenedor se reinicia automáticamente si falla el health check
