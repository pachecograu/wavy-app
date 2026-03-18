import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import '../socket/socket_service.dart';

class MicStreamService {
  static final SocketService _socket = SocketService();
  static FlutterSoundRecorder? _recorder;
  static FlutterSoundPlayer? _player;
  static String? _waveId;
  static bool _isListening = false;
  static bool _isBroadcasting = false;

  /// DJ: start capturing mic and streaming via socket
  static Future<void> startBroadcasting(String waveId) async {
    if (_isBroadcasting) return;
    _waveId = waveId;

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('❌ Microphone permission denied');
      return;
    }

    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
    _isBroadcasting = true;

    final controller = StreamController<Uint8List>();

    // Send chunks directly as they arrive, throttled
    int lastSendTime = 0;
    controller.stream.listen((data) {
      if (!_isBroadcasting) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastSendTime > 250) {
        lastSendTime = now;
        _socket.emit('mic-audio', {
          'waveId': _waveId,
          'audio': base64Encode(data),
        });
      }
    });

    await _recorder!.startRecorder(
      toStream: controller.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 16000,
    );
    debugPrint('🎙️ Mic broadcasting started');
  }

  /// DJ: stop capturing
  static Future<void> stopBroadcasting() async {
    _isBroadcasting = false;
    try {
      await _recorder?.stopRecorder();
      await _recorder?.closeRecorder();
    } catch (_) {}
    _recorder = null;
    debugPrint('🎙️ Mic broadcasting stopped');
  }

  /// Oyente: start listening for mic audio from DJ
  static Future<void> startListening(String waveId) async {
    if (_isListening) return;
    _isListening = true;
    _waveId = waveId;

    _player = FlutterSoundPlayer();
    await _player!.openPlayer();
    await _player!.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 16000,
      bufferSize: 8192,
      interleaved: true,
    );

    _socket.on('mic-audio-data', (data) {
      try {
        final audioBase64 = data['audio']?.toString();
        if (audioBase64 != null && _player != null) {
          final bytes = Uint8List.fromList(base64Decode(audioBase64));
          debugPrint('🎙️ Received mic chunk: ${bytes.length} bytes');
          _player!.uint8ListSink?.add(bytes);
        }
      } catch (e) {
        debugPrint('Error playing mic audio: $e');
      }
    });

    debugPrint('🎧 Listening for DJ mic audio');
  }

  /// Oyente: stop listening
  static Future<void> stopListening() async {
    _socket.off('mic-audio-data');
    _isListening = false;
    try {
      await _player?.stopPlayer();
      await _player?.closePlayer();
    } catch (_) {}
    _player = null;
  }
}
