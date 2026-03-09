import 'audio_service.dart';
import 'voice_service.dart';
import 'socket_service.dart';
import 'dart:math';

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
  bool _isWaitingForVoiceToken = false;
  bool _isStreamingBits = false;

  Future<void> joinRoom(String roomId, String userId, {bool isHost = false}) async {
    // Prevent multiple simultaneous join attempts
    if (_isInRoom || _currentRoomId == roomId) {
      print('⚠️ Already in room $roomId or joining in progress');
      return;
    }
    
    try {
      print('🌊 Joining hybrid room: $roomId as $userId (isHost: $isHost)');
      
      _currentRoomId = roomId;
      
      // First connect socket and wait
      await _socketService.joinHybridRoom(roomId, userId, isHost: isHost);
      
      // Then setup listeners after connection is established
      _setupSocketListeners();
      
      _isInRoom = true;
      print('🌊 Successfully joined hybrid room');
      
      // Auto-start streaming if this is the host (emisor)
      if (isHost) {
        Future.delayed(const Duration(seconds: 1), () {
          startBitsStreaming();
        });
      }
    } catch (e) {
      print('❌ Error joining room: $e');
      _currentRoomId = null; // Reset on error
      throw Exception('Error joining room: $e');
    }
  }

  void _setupSocketListeners() {
    // Remove the connection check since we call this after connection
    _socketService.onHybridRoomJoined((data) async {
      print('🌊 Room joined event received: $data');
      
      if (_currentRoomId != null) {
        try {
          await _audioService.startMusicStream(_currentRoomId!);
        } catch (e) {
          print('⚠️ Could not start HLS stream, continuing without music: $e');
        }
      }
    });

    _socketService.onVoiceTokenGranted((data) async {
      print('🎙️ Voice token received: ${data.keys}');
      
      final token = data['token'];
      
      if (token != null && _currentRoomId != null) {
        try {
          await _voiceService.connectToVoiceRoom(_currentRoomId!, token);
          _isWaitingForVoiceToken = false;
        } catch (e) {
          print('❌ Failed to connect to voice room: $e');
          _isWaitingForVoiceToken = false;
        }
      }
    });

    _socketService.onError((data) {
      print('❌ Socket error: ${data['message']}');
      _isWaitingForVoiceToken = false;
    });
  }

  Future<void> leaveRoom() async {
    print('🌊 Leaving hybrid room');
    
    stopBitsStreaming();
    await _audioService.stopMusicStream();
    await _voiceService.disconnect();
    _socketService.leaveHybridRoom();
    
    _isInRoom = false;
    _currentRoomId = null;
    _isWaitingForVoiceToken = false;
  }

  Future<void> requestMicrophone() async {
    if (_isWaitingForVoiceToken) {
      print('⚠️ Already waiting for voice token');
      return;
    }
    
    if (!_voiceService.isConnected) {
      print('🎙️ Requesting voice token...');
      _isWaitingForVoiceToken = true;
      _socketService.requestVoiceToken();
      
      Future.delayed(const Duration(seconds: 10), () {
        if (_isWaitingForVoiceToken) {
          _isWaitingForVoiceToken = false;
          print('⚠️ Voice token request timed out');
        }
      });
    } else {
      await _voiceService.enableMicrophone();
    }
  }

  Future<void> releaseMicrophone() async {
    await _voiceService.disableMicrophone();
  }

  Future<void> setMusicVolume(double volume) async {
    await _audioService.setMusicVolume(volume);
  }

  // Streaming de bits para emisores
  void startBitsStreaming() {
    if (_isStreamingBits || _currentRoomId == null) return;
    
    _isStreamingBits = true;
    startAudioStreaming();
  }

  void startAudioStreaming() {
    if (_currentRoomId == null) return;
    
    // Usar el sistema simple directo
    _socketService.emit('user-connected', {'userId': 'emisor-123'});
    _socketService.emit('create-wave', {
      'userId': 'emisor-123',
      'name': 'Live Wave',
      'djName': 'DJ Live'
    });
    
    _socketService.emit('start-song', {
      'waveId': 'test-wave',
      'songData': {'title': 'Live Song', 'artist': 'DJ Live'}
    });
    
    _socketService.emit('song-control', {
      'waveId': 'test-wave',
      'action': 'play',
      'currentTime': 0.0
    });
    
    _streamAudioLoop();
    _streamBitsLoop();
  }

  void _streamAudioLoop() async {
    if (_currentRoomId == null) return;
    
    final audioBuffer = List.generate(1024, (i) => 0.1 * sin(440.0 * 2 * pi * i / 44100.0));
    _socketService.emit('live-audio', {
      'waveId': 'test-wave',
      'audioBuffer': audioBuffer,
    });
    
    await Future.delayed(const Duration(milliseconds: 100));
    _streamAudioLoop();
  }

  void _streamBitsLoop() async {
    if (!_isStreamingBits || _currentRoomId == null) return;
    
    final bitsData = _generateSimulatedBits(128);
    _socketService.emit('stream-bits', {
      'waveId': 'test-wave',
      'bitsData': bitsData,
      'byteSize': 16,
    });
    
    await Future.delayed(const Duration(milliseconds: 100));
    _streamBitsLoop();
  }

  String _generateSimulatedBits(int length) {
    final random = DateTime.now().millisecondsSinceEpoch;
    String bits = '';
    
    for (int i = 0; i < length; i++) {
      bits += ((random + i) % 2).toString();
    }
    
    return bits;
  }

  void stopBitsStreaming() {
    _isStreamingBits = false;
    print('📡 Deteniendo streaming de bits...');
  }

  bool get isInRoom => _isInRoom;
  bool get isMusicPlaying => _audioService.isMusicPlaying;
  bool get isMicEnabled => _voiceService.isMicEnabled;
  bool get isVoiceConnected => _voiceService.isConnected;
  bool get isWaitingForVoiceToken => _isWaitingForVoiceToken;
  bool get isStreamingBits => _isStreamingBits;
  
  Stream get positionStream => _audioService.positionStream;
  Stream get participantsStream => _voiceService.participantsStream;
}