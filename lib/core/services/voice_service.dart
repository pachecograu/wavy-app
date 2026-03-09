import 'package:livekit_client/livekit_client.dart';
import '../config/app_config.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  Room? _room;
  bool _isConnected = false;
  bool _isMicEnabled = false;
  
  Future<void> connectToVoiceRoom(String roomId, String token) async {
    try {
      print('🎙️ Connecting to voice room: $roomId');
      
      _room = Room();
      
      // Configuración de audio para voz
      _room!.localParticipant?.setMicrophoneEnabled(false);
      
      await _room!.connect(
        AppConfig.liveKitUrl,
        token,
      );
      
      _isConnected = true;
      print('🎙️ Connected to voice room successfully');
    } catch (e) {
      print('❌ Error connecting to voice room: $e');
      throw Exception('Error connecting to voice room: $e');
    }
  }

  Future<void> enableMicrophone() async {
    if (_room != null && _isConnected) {
      try {
        await _room!.localParticipant?.setMicrophoneEnabled(true);
        _isMicEnabled = true;
        print('🎙️ Microphone enabled');
      } catch (e) {
        print('❌ Error enabling microphone: $e');
        rethrow;
      }
    } else {
      print('⚠️ Cannot enable microphone: not connected to voice room');
    }
  }

  Future<void> disableMicrophone() async {
    if (_room != null && _isConnected) {
      try {
        await _room!.localParticipant?.setMicrophoneEnabled(false);
        _isMicEnabled = false;
        print('🎙️ Microphone disabled');
      } catch (e) {
        print('❌ Error disabling microphone: $e');
        rethrow;
      }
    }
  }

  Future<void> disconnect() async {
    if (_room != null) {
      try {
        await _room!.disconnect();
        _room = null;
        _isConnected = false;
        _isMicEnabled = false;
        print('🎙️ Disconnected from voice room');
      } catch (e) {
        print('❌ Error disconnecting from voice room: $e');
      }
    }
  }

  // Getters
  bool get isConnected => _isConnected;
  bool get isMicEnabled => _isMicEnabled;
  Room? get room => _room;
  
  // Streams para UI
  Stream<List<RemoteParticipant>> get participantsStream {
    if (_room != null) {
      return Stream.value(_room!.remoteParticipants.values.toList());
    }
    return const Stream.empty();
  }
}