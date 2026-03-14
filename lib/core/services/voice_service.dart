import 'package:flutter/foundation.dart';
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
      debugPrint('🎙️ Connecting to voice room: $roomId');

      _room = Room();
      _room!.localParticipant?.setMicrophoneEnabled(false);

      await _room!.connect(
        AppConfig.liveKitUrl,
        token,
      );

      _isConnected = true;
      debugPrint('🎙️ Connected to voice room successfully');
    } catch (e) {
      debugPrint('❌ Error connecting to voice room: $e');
      throw Exception('Error connecting to voice room: $e');
    }
  }

  Future<void> enableMicrophone() async {
    if (_room != null && _isConnected) {
      try {
        await _room!.localParticipant?.setMicrophoneEnabled(true);
        _isMicEnabled = true;
        debugPrint('🎙️ Microphone enabled');
      } catch (e) {
        debugPrint('❌ Error enabling microphone: $e');
        rethrow;
      }
    } else {
      debugPrint('⚠️ Cannot enable microphone: not connected to voice room');
    }
  }

  Future<void> disableMicrophone() async {
    if (_room != null && _isConnected) {
      try {
        await _room!.localParticipant?.setMicrophoneEnabled(false);
        _isMicEnabled = false;
        debugPrint('🎙️ Microphone disabled');
      } catch (e) {
        debugPrint('❌ Error disabling microphone: $e');
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
        debugPrint('🎙️ Disconnected from voice room');
      } catch (e) {
        debugPrint('❌ Error disconnecting from voice room: $e');
      }
    }
  }

  bool get isConnected => _isConnected;
  bool get isMicEnabled => _isMicEnabled;
  Room? get room => _room;

  Stream<List<RemoteParticipant>> get participantsStream {
    if (_room != null) {
      return Stream.value(_room!.remoteParticipants.values.toList());
    }
    return const Stream.empty();
  }
}
