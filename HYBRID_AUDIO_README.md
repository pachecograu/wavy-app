# WAVY - Arquitectura Híbrida de Audio

## 🎯 Implementación Completa

Esta implementación sigue la **recomendación final** de arquitectura híbrida:

- **🎵 MÚSICA → HLS (HTTP Streaming)**
- **🎙️ VOZ → WebRTC (LiveKit)**

## 📁 Estructura de Archivos

```
lib/
├── core/
│   ├── config/
│   │   └── app_config.dart          # URLs y configuración
│   └── services/
│       ├── audio_service.dart       # HLS con just_audio
│       ├── voice_service.dart       # WebRTC con LiveKit
│       └── hybrid_audio_service.dart # Coordinador principal
└── widgets/
    └── hybrid_audio_player.dart     # Widget de ejemplo
```

## 🔧 Configuración

### AppConfig
- **HLS Stream**: `${backendUrl}/hls`
- **LiveKit WebRTC**: Puerto 7880
- **Socket.IO**: Para realtime
- **Formatos**: AAC (música), Opus (voz)

### Dependencias Clave
```yaml
just_audio: ^0.9.46      # HLS streaming
livekit_client: ^2.0.0   # WebRTC gestionado
socket_io_client: ^2.0.3 # Realtime
```

## 🚀 Flujo de Funcionamiento

### 1. Unirse a Sala
```dart
await hybridService.joinRoom('room123');
```
- Conecta Socket.IO
- Inicia stream HLS de música
- WebRTC se conecta SOLO cuando se necesita

### 2. Música (Siempre Activa)
- **Protocolo**: HTTP/HLS
- **Latencia**: 2-4 segundos (aceptable)
- **Escalabilidad**: Ilimitada con CDN
- **Costo**: Muy bajo

### 3. Voz (Bajo Demanda)
- **Protocolo**: WebRTC/LiveKit
- **Latencia**: <100ms
- **Uso**: Solo cuando hay mic activos
- **Costo**: Variable según uso

## 💡 Ventajas de Esta Arquitectura

### ✅ Económica
- HLS es barato para muchos oyentes
- WebRTC solo se usa cuando necesario
- CDN reduce costos de ancho de banda

### ✅ Escalable
- Miles de oyentes con HLS
- WebRTC limitado a participantes con mic
- Sin problemas de CPU en dispositivos

### ✅ Compatible
- Android ✅
- iOS ✅  
- Web ✅
- just_audio funciona en todas las plataformas

### ✅ Estable
- HLS maneja reconexiones automáticamente
- WebRTC solo para interacción crítica
- Fallback graceful si falla la voz

## 🎮 Uso del Widget

```dart
HybridAudioPlayer(roomId: 'mi-sala')
```

El widget muestra:
- Control de volumen de música
- Botones para pedir/soltar micrófono
- Lista de participantes con voz activa

## 🔄 Estados del Sistema

| Componente | Estado | Descripción |
|------------|--------|-------------|
| Música HLS | Siempre ON | Stream continuo HTTP |
| WebRTC | Bajo demanda | Solo con mic activos |
| Socket.IO | Siempre ON | Chat y control |

## 📊 Estimación de Costos

Para 1000 oyentes simultáneos:

| Componente | Costo/mes |
|------------|-----------|
| HLS + CDN | $20-50 |
| WebRTC (10 mics) | $10-30 |
| Backend VPS | $10-20 |
| **Total** | **$40-100** |

## 🛠️ Próximos Pasos

1. **Backend**: Implementar servidor HLS + LiveKit
2. **Tokens**: Sistema de autenticación para WebRTC
3. **CDN**: Configurar CloudFront/CloudFlare para HLS
4. **Monitoring**: Métricas de calidad de audio

## 🎯 Resultado Final

Esta arquitectura te da:
- **Música estable** para miles de usuarios
- **Voz en tiempo real** cuando se necesita
- **Costos optimizados** según uso real
- **Compatibilidad total** con Flutter

¡Exactamente lo que usan las plataformas grandes! 🚀