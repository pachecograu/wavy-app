import 'package:flutter/foundation.dart';
import 'webrtc_voice_service.dart';
import 'music_service.dart';
import '../socket/socket_service.dart';
import '../models/track.dart';

class HybridAudioService {
  static HybridAudioService? _instance;
  factory HybridAudioService() {
    _instance ??= HybridAudioService._internal();
    return _instance!;
  }
  HybridAudioService._internal();

  final WebRTCVoiceService _voice = WebRTCVoiceService();
  final SocketService _socket = SocketService();

  bool _isInRoom = false;
  String? _currentRoomId;
  bool _socketListenerSetup = false;

  bool get isInRoom => _isInRoom;
  bool get isMicEnabled => _voice.isMicEnabled;
  bool get isVoiceConnected => _voice.isInitialized;
  Stream<P2PLocalTrack> get incomingLocalTrackStream => _voice.incomingTrackStream;

  Future<void> joinRoom(String roomId, String userId, {bool isHost = false}) async {
    if (_isInRoom && _currentRoomId == roomId) return;
    _currentRoomId = roomId;

    // Emit join – backend responds via hybrid_room_joined
    _socket.emit('join_hybrid_room', {
      'roomId': roomId,
      'userId': userId,
      'isHost': isHost,
    });

    if (!_socketListenerSetup) {
      _socketListenerSetup = true;
      _socket.on('hybrid_room_joined', (data) async {
        debugPrint('🌊 Joined hybrid room (S3-direct music, WebRTC voice)');
        final hostUserId = data['hostUserId']?.toString();
        final micActive = data['micActive'] == true;
        // Initialize WebRTC with info from the server
        await _voice.initialize(
          roomId,
          userId,
          isHost: isHost,
          hostUserId: hostUserId,
          micActive: micActive,
        );
      });
    }

    _isInRoom = true;
  }

  Future<void> leaveRoom() async {
    await MusicService.audioPlayer.stop();
    await _voice.dispose();
    _socket.emit('leave_hybrid_room', {});
    _isInRoom = false;
    _currentRoomId = null;
    _socketListenerSetup = false;
    debugPrint('🌊 Left hybrid room');
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (enabled) {
      await _voice.enableMicrophone();
    } else {
      await _voice.disableMicrophone();
    }
  }

  // Kept for API compatibility with wave_home_screen
  Future<void> ensureVoiceConnected() async {
    // WebRTC doesn't need a separate connection step; mic is peer-to-peer.
    debugPrint('🎙️ ensureVoiceConnected – WebRTC is always ready once initialized');
  }

  Future<void> requestMicrophone() => _voice.enableMicrophone();
  Future<void> releaseMicrophone() => _voice.disableMicrophone();

  Future<bool> broadcastLocalTrack(Track track) async {
    final localPath = track.url;
    if (localPath == null || localPath.isEmpty) return false;
    return _voice.broadcastLocalTrack(localPath, track.title);
  }
}
