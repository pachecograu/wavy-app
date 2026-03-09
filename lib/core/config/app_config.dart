import 'package:flutter/foundation.dart';

class AppConfig {
  static String get backendUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    } else {
      // Android - use localhost for emulator, IP for physical device
      return 'http://10.0.2.2:3000'; // Android emulator
      // return 'http://192.168.1.11:3000'; // Physical device
    }
  }
  
  // Socket.IO para realtime
  static String get socketUrl => backendUrl;
  static String get apiUrl => '$backendUrl/api';
  
  // HLS para música (HTTP streaming)
  static String get hlsStreamUrl => '$backendUrl/hls';
  
  // WebRTC para voz (LiveKit)
  static String get liveKitUrl {
    if (kIsWeb) {
      return 'ws://localhost:7880';
    } else {
      // Android - use localhost for emulator, IP for physical device
      return 'ws://10.0.2.2:7880'; // Android emulator
      // return 'ws://192.168.1.11:7880'; // Physical device
    }
  }
  
  // Configuración de audio
  static const String musicFormat = 'aac'; // AAC para música
  static const String voiceFormat = 'opus'; // Opus para voz
  static const int hlsSegmentDuration = 2; // 2 segundos por segmento
  static const int maxVoiceParticipants = 10; // Máximo en mic
}