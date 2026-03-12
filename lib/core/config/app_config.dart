import 'package:flutter/foundation.dart';

class AppConfig {
  // AWS Application Load Balancer URL (producción)
  static const String _productionUrl = 'http://wavy-alb-1189004548.us-east-1.elb.amazonaws.com';
  
  static String get backendUrl => _productionUrl;
  
  // Socket.IO para realtime
  static String get socketUrl => backendUrl;
  static String get apiUrl => '$backendUrl/api';
  
  // HLS para música (HTTP streaming)
  static String get hlsStreamUrl => '$backendUrl/hls';
  
  // WebRTC para voz (LiveKit)
  // El backend retorna la URL correcta en el token
  static String get liveKitUrl => 'ws://wavy-alb-1189004548.us-east-1.elb.amazonaws.com:7880';
  
  // Configuración de audio
  static const String musicFormat = 'aac'; // AAC para música
  static const String voiceFormat = 'opus'; // Opus para voz
  static const int hlsSegmentDuration = 2; // 2 segundos por segmento
  static const int maxVoiceParticipants = 10; // Máximo en mic
}