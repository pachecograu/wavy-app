import 'package:flutter/foundation.dart';
import 'audio_service.dart';
import 'voice_service.dart';
import '../socket/socket_service.dart';

class HybridAudioService {
  static HybridAudioService? _instance;
  factory HybridAudioService() {
    _instance ??= HybridAudioService._internal();
    return _instance!;
  }
  HybridAudioService._internal();

  final AudioService _audioService = AudioService();
  final VoiceService _voiceService = VoiceService();
  final SocketService _socketService = SocketService();

  bool _isInRoom = false;
  String? _currentRoomId;

  bool get isInRoom => _isInRoom;
  bool get isMicEnabled => _voiceService.isMicEnabled;
  bool get isVoiceConnected => _voiceService.isConnected;

  Future<void> joinRoom(String roomId, String userId, {bool isHost = false}) async {
    if (_isInRoom || _currentRoomId == roomId) return;

    _currentRoomId = roomId;

    _socketService.emit('join_hybrid_room', {
      'roomId': roomId,
      'userId': userId,
      'isHost': isHost,
    });

    _setupSocketListeners();
    _isInRoom = true;
  }

  void _setupSocketListeners() {
    _socketService.on('hybrid_room_joined', (data) async {
      if (_currentRoomId != null) {
        try {
          await _audioService.startMusicStream(_currentRoomId!);
        } catch (e) {
          debugPrint('⚠️ Could not start HLS stream: $e');
        }
      }
    });

    _socketService.on('voice_token_granted', (data) async {
      final token = data['token'];
      if (token != null && _currentRoomId != null) {
        try {
          await _voiceService.connectToVoiceRoom(_currentRoomId!, token);
        } catch (e) {
          debugPrint('❌ Failed to connect to voice room: $e');
        }
      }
    });
  }

  Future<void> leaveRoom() async {
    await _audioService.stopMusicStream();
    await _voiceService.disconnect();
    _socketService.emit('leave_hybrid_room', {});
    _isInRoom = false;
    _currentRoomId = null;
  }

  Future<void> requestMicrophone() async {
    if (!_voiceService.isConnected) {
      _socketService.emit('request_voice_token', {'roomId': _currentRoomId});
    } else {
      await _voiceService.enableMicrophone();
    }
  }

  Future<void> releaseMicrophone() async {
    await _voiceService.disableMicrophone();
  }
}
