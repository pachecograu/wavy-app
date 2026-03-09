import 'dart:async';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import '../socket/socket_service.dart';

class StreamingService {
  static final StreamingService _instance = StreamingService._internal();
  factory StreamingService() => _instance;
  StreamingService._internal();

  Room? _room;
  LocalAudioTrack? _audioTrack;
  final SocketService _socketService = SocketService();
  
  StreamController<RemoteAudioTrack>? _remoteStreamController;
  StreamController<String>? _broadcastEventController;
  
  Stream<RemoteAudioTrack>? get remoteStreamStream => _remoteStreamController?.stream;
  Stream<String>? get broadcastEventStream => _broadcastEventController?.stream;
  
  bool get isStreaming => _audioTrack != null;
  
  Future<void> initializeStreaming() async {
    _remoteStreamController ??= StreamController<RemoteAudioTrack>.broadcast();
    _broadcastEventController ??= StreamController<String>.broadcast();
    
    _room = Room();
    
    _room!.addListener(_onRoomUpdate);
    
    print('✅ LiveKit streaming service initialized');
  }
  
  void _onRoomUpdate() {
    _room!.remoteParticipants.values.forEach((participant) {
      for (var track in participant.audioTracks) {
        if (track.track != null) {
          _remoteStreamController?.add(track.track as RemoteAudioTrack);
        }
      }
    });
  }
  
  Future<void> startBroadcast(String waveId) async {
    try {
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        throw Exception('Microphone permission denied');
      }
      
      // Create audio track
      _audioTrack = await LocalAudioTrack.create(AudioCaptureOptions(
        echoCancellation: false,
        noiseSuppression: false,
        autoGainControl: false,
      ));
      
      // Connect to LiveKit room (you'll need your LiveKit server URL)
      const url = 'wss://your-livekit-server.com';
      const token = 'your-jwt-token'; // Generate this on your backend
      
      await _room!.connect(url, token);
      
      // Publish audio track
      await _room!.localParticipant?.publishAudioTrack(_audioTrack!);
      
      // Notify via socket
      _socketService.emit('broadcast-offer', {
        'waveId': waveId,
        'type': 'livekit-audio',
        'roomName': waveId,
      });
      
      print('🎙️ LiveKit broadcast started for wave: $waveId');
      
    } catch (e) {
      print('❌ Error starting broadcast: $e');
      rethrow;
    }
  }
  
  Future<void> joinStream(String waveId) async {
    try {
      // Connect to the same LiveKit room
      const url = 'wss://your-livekit-server.com';
      const token = 'your-listener-jwt-token';
      
      await _room!.connect(url, token);
      
      _socketService.on('broadcast-offer', (data) async {
        print('📡 Received broadcast offer for wave: ${data['waveId']}');
      });
      
      _socketService.on('stop-broadcast', (data) async {
        _broadcastEventController?.add('broadcast-ended');
        await _cleanupConnection();
      });
      
      print('🎧 Joined LiveKit stream for wave: $waveId');
      
    } catch (e) {
      print('❌ Error joining stream: $e');
    }
  }
  
  Future<void> startBroadcastWithMusic(String waveId, String? musicFilePath) async {
    try {
      await startBroadcast(waveId);
      
      if (musicFilePath != null) {
        print('🎵 Music streaming with LiveKit: $musicFilePath');
        // TODO: Mix music with microphone using LiveKit audio processing
      }
      
    } catch (e) {
      print('❌ Error starting broadcast with music: $e');
      rethrow;
    }
  }
  
  Future<void> _cleanupConnection() async {
    try {
      await _audioTrack?.stop();
      await _room?.disconnect();
      
      _audioTrack = null;
      
      print('🧹 LiveKit connection cleaned up');
    } catch (e) {
      print('❌ Error cleaning up: $e');
    }
  }

  Future<void> stopStreaming() async {
    try {
      _socketService.emit('stop-broadcast', {'waveId': 'current-wave'});
      await _cleanupConnection();
    } catch (e) {
      print('❌ Error stopping stream: $e');
    }
  }
  
  void dispose() {
    _cleanupConnection();
    _remoteStreamController?.close();
    _broadcastEventController?.close();
    _remoteStreamController = null;
    _broadcastEventController = null;
  }
}