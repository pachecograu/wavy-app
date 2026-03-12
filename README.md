# 🌊 WAVY App

Flutter app for WAVY - Live Audio Social Platform

## 🎯 What is WAVY?

WAVY is a live audio social platform where users can:
- **Share music** in real-time with others
- **Listen together** to live audio streams  
- **Interact socially** through chat and voice
- **Create communities** around shared music experiences

## 🧱 Architecture

- **Flutter** (Android, iOS, Web)
- **Socket.IO** for real-time communication
- **WebRTC** for audio streaming
- **Provider** for state management
- **Premium UI** with red color scheme

## 🚀 Quick Start

1. **Prerequisites**
   - Flutter SDK 3.10.1+
   - Android Studio / Xcode

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run on Android**
   ```bash
   flutter run -d android
   ```

4. **Run on Web**
   ```bash
   flutter run -d chrome
   ```

## 🌐 Backend Configuration

The app is configured to connect to AWS backend:

**Backend URL**: `http://wavy-alb-1189004548.us-east-1.elb.amazonaws.com`

Configuration file: `lib/core/config/app_config.dart`

## 📱 Features

### Core Features
- ✅ Real-time audio streaming
- ✅ Live chat (public & private)
- ✅ Wave creation and joining
- ✅ Listener count tracking
- ✅ Mic invitations for listeners

### UI Features  
- ✅ Premium dark theme with red accents
- ✅ Reactive particle background
- ✅ Sliding panels for chat and playlists
- ✅ Smooth animations and transitions

### Social Features
- ✅ Public chat for all listeners
- ✅ Private chat (owner ↔ listener only)
- ✅ Live reactions (⭐❤️🔥)
- ✅ Mic invitations and voice interaction

## 🎨 UI Structure

```
Stack
├── Particle Background (reactive to audio)
└── Main Content
    ├── Wave Info (name, DJ, listeners, status)
    ├── Audio Player
    ├── Chat Slide Panel →
    ├── Playlist Slide Panel → (owner only)
    └── Discover Waves Panel → (listeners only)
```

## 🔐 User Roles

### Listener
- Listen to audio streams
- Send public messages
- Receive private messages from owner
- Accept mic invitations
- Switch between waves

### Owner (Broadcaster)
- Control audio stream
- Manage playlist
- Send public/private messages
- Invite listeners to mic
- Moderate chat

## 🧩 State Management

Using **Provider** pattern:
- `AuthProvider` - User authentication
- `WaveProvider` - Wave state and audio
- `ChatProvider` - Chat messages
- `UIProvider` - Slide panels and navigation

## 📦 Dependencies

### Core
- `socket_io_client` - Real-time communication
- `flutter_webrtc` - Audio streaming
- `just_audio` - Audio playback
- `provider` - State management
- `livekit_client` - WebRTC voice

### UI & Utils
- `flutter_animate` - Smooth animations
- `permission_handler` - Microphone permissions
- `shared_preferences` - Local storage

## 🎵 Audio Flow

1. **Owner** starts broadcasting
2. **Backend** creates wave and notifies clients
3. **Listeners** join wave and receive audio stream
4. **Real-time** sync ensures everyone hears the same thing
5. **Mic invitations** allow voice interaction

## 🚀 Build for Production

### Android
```bash
flutter build apk --release
```

### iOS  
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## 📚 Documentation

- **AWS Deployment**: See `AWS_ALB_DEPLOYMENT.md`
- **Backend Repository**: [wavy-backend](https://github.com/pachecograu/wavy-backend)

---

Built with ❤️ for the WAVY community
