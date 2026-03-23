# WAVY App (Frontend)

Aplicación Flutter para la experiencia en vivo de WAVY: waves, chat en tiempo real, voz por WebRTC y reproducción sincronizada.

## Estado actual

- Proyecto activo en este repo: Android + Web.
- Arquitectura de estado con `Provider`.
- Señalización y eventos en tiempo real con `Socket.IO`.
- Reproducción musical con `just_audio` + `audio_service`.
- Voz y transporte P2P con `flutter_webrtc`.

## Flujo funcional

### Roles

- **Oyente**
  - Se conecta a una wave existente.
  - Recibe audio en vivo y sincronización de reproducción.
  - Participa en chat/reacciones.
  - Puede subir al micrófono por invitación.

- **DJ (emisor)**
  - Crea/gestiona su wave.
  - Inicia y controla reproducción.
  - Envía audio local a oyentes por canal P2P.
  - Gestiona locutores e interacción social.

### Ciclo general

1. `AuthProvider` inicializa usuario anónimo por dispositivo.
2. `WaveProvider` crea o conecta la wave.
3. `HybridAudioService`/`WebRTCVoiceService` establecen voz y transporte P2P.
4. `TrackProvider` + `MusicService` gestionan pista actual y reproducción.
5. `PlaybackSyncService` corrige drift y mantiene sincronía DJ/oyentes.
6. `ChatProvider` y `VoiceProvider` manejan chat, reacciones e invitaciones a mic.

## Arquitectura (código real)

### Providers principales

- `AuthProvider`: identidad local, sesión y conexión inicial al socket.
- `WaveProvider`: estado de wave, creación/unión/salida y ownership.
- `TrackProvider`: pista actual, lista de tracks y estado de reproducción compartido.
- `VoiceProvider`: permisos de locutor, invitaciones, control de micrófono.
- `ChatProvider`: mensajes públicos/privados.
- `QualityProvider`: métricas de calidad local/resumen por oyente.

### Servicios clave

- `SocketService`: singleton para conexión, reconexión y eventos Socket.IO.
- `MusicService`: control del `AudioPlayer`, catálogo S3 y reproducción local/remota.
- `WebRTCVoiceService`:
  - señalización WebRTC;
  - voz entre peers;
  - DataChannel para envío de programa (`program_start/chunk/end/stop`);
  - relay local HTTP (`127.0.0.1`) para alimentar `just_audio` en oyentes.
- `HybridAudioService`: orquesta entrada/salida de sala y puente con voz WebRTC.
- `PlaybackSyncService`: sincronización de tiempo/posición entre DJ y oyentes.
- `NotificationService`: inicialización y notificaciones locales.

## Configuración backend

Configuración central en `lib/core/config/app_config.dart`:

- `backendUrl`: `https://wavy-alb-1189004548.us-east-1.elb.amazonaws.com`
- `socketUrl`: mismo host del backend.
- `apiUrl`: `$backendUrl/api`
- `hlsStreamUrl`: `http://wavy-alb-1189004548.us-east-1.elb.amazonaws.com/hls`

Nota: el proyecto define `HttpOverrides` permisivo en `main.dart` para certificados.

## Estructura relevante

- `lib/main.dart`: bootstrap (`AudioService`, providers, app root).
- `lib/core/config/app_config.dart`: endpoints y constantes de audio.
- `lib/core/socket/socket_service.dart`: transporte de eventos real-time.
- `lib/core/services/`: música, sincronización, voz WebRTC, notificaciones.
- `lib/features/*/providers/`: estado por dominio (auth, wave, chat, track, voice, quality).
- `lib/features/wave/screens/wave_home_screen.dart`: pantalla principal operativa.

## Ejecutar local

### Requisitos

- Flutter SDK `>=3.8.1 <4.0.0`
- Dart SDK compatible con la versión de Flutter instalada
- Android SDK (para ejecutar en dispositivo/emulador Android)

### Comandos

```bash
flutter pub get
flutter run -d android
```

Para web:

```bash
flutter run -d chrome
```

## Build

```bash
flutter build apk --release
flutter build web --release
```

## Permisos Android usados

Definidos en `android/app/src/main/AndroidManifest.xml`:

- `INTERNET`
- `RECORD_AUDIO`
- `MODIFY_AUDIO_SETTINGS`
- `ACCESS_NETWORK_STATE`
- `CAMERA`
- `WAKE_LOCK`
- `FOREGROUND_SERVICE`
- `FOREGROUND_SERVICE_MEDIA_PLAYBACK`
- `POST_NOTIFICATIONS`

## Troubleshooting rápido

- Si el oyente no recibe audio, validar conexión socket + eventos de señalización WebRTC.
- Si hay cortes/reconexión en reproducción, revisar relay local y estado de DataChannel.
- Si falla reproducción remota, validar URL efectiva en `TrackProvider` y `MusicService`.
- Si el mic no transmite, verificar permisos Android y estado de invitación en `VoiceProvider`.

## Documentación relacionada

- Infra app/backend: `AWS_ALB_DEPLOYMENT.md`
- Backend API/socket: repo `wavy-backend`
