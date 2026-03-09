# 🌊 WAVY - Deployment Guide (Android & Web)

## 📱 Plataformas Soportadas
- ✅ **Android** (APK/AAB)
- ✅ **Web** (PWA)
- ❌ iOS (Removido)
- ❌ Desktop (Removido)

## 🚀 Build Commands

### Android
```bash
# Debug APK
flutter run -d android

# Release APK
flutter build apk --release

# Release AAB (Google Play)
flutter build appbundle --release
```

### Web
```bash
# Debug Web
flutter run -d chrome

# Release Web
flutter build web --release
```

### Ambos (Script)
```bash
# Windows
build-release.bat
```

## 📁 Output Locations

### Android
- **APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **AAB**: `build/app/outputs/bundle/release/app-release.aab`

### Web
- **Web**: `build/web/` (Deploy completo)

## 🔧 Configuración

### Android Permissions
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

### Web Configuration
```html
<!-- web/index.html -->
<script src="https://cdn.socket.io/4.7.2/socket.io.min.js"></script>
```

## 🌐 URLs de Configuración

### Desarrollo
- **Android**: `http://192.168.1.11:3000`
- **Web**: `http://localhost:3000`

### Producción
Actualizar en `lib/core/config/app_config.dart`:
```dart
static String get backendUrl {
  if (kIsWeb) {
    return 'https://your-domain.com';
  } else {
    return 'https://your-domain.com';
  }
}
```

## 📦 Deployment

### Android
1. **Google Play Store**:
   - Usar `app-release.aab`
   - Subir a Google Play Console

2. **APK Directo**:
   - Usar `app-release.apk`
   - Distribuir directamente

### Web
1. **Hosting Estático**:
   - Subir carpeta `build/web/`
   - Netlify, Vercel, Firebase Hosting

2. **Servidor Propio**:
   - Nginx/Apache
   - Servir archivos estáticos

## ✅ Verificación

### Android
```bash
flutter doctor
flutter devices
```

### Web
```bash
flutter config --enable-web
flutter devices
```

## 🎯 Resultado Final
- **Android APK**: ~15-25 MB
- **Web Build**: ~5-10 MB
- **Funcionalidades**: HLS + WebRTC + Socket.IO