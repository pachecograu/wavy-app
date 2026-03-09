import 'dart:math';
import 'socket_service.dart';

class SimpleAudioEmitter {
  final SocketService _socket = SocketService();
  bool _isStreaming = false;
  String? _waveId;

  Future<void> startStreaming() async {
    if (_isStreaming) return;
    
    await _socket.connect();
    _socket.emit('user-connected', {'userId': 'emisor-123'});
    _socket.emit('create-wave', {
      'userId': 'emisor-123',
      'name': 'Test Wave',
      'djName': 'DJ Test'
    });
    
    _waveId = 'test-wave';
    _isStreaming = true;
    
    // Iniciar canción usando los métodos del SocketService
    _socket.startSong(_waveId!, {
      'title': 'Test Song', 
      'artist': 'Test Artist'
    });
    
    _socket.controlSong(_waveId!, 'play', 0.0);
    
    // Iniciar loops
    _streamAudio();
    _streamBits();
  }

  void _streamAudio() async {
    if (!_isStreaming || _waveId == null) return;
    
    final audioBuffer = List.generate(1024, (i) => 0.1 * sin(440.0 * 2 * pi * i / 44100.0));
    _socket.streamLiveAudio(_waveId!, audioBuffer);
    
    // También enviar como audio-stream para compatibilidad
    _socket.streamAudio(_waveId!, audioBuffer);
    
    await Future.delayed(const Duration(milliseconds: 100));
    _streamAudio();
  }

  void _streamBits() async {
    if (!_isStreaming || _waveId == null) return;
    
    final bits = List.generate(128, (i) => (i % 2).toString()).join('');
    _socket.streamBits(_waveId!, bits, 16);
    
    await Future.delayed(const Duration(milliseconds: 100));
    _streamBits();
  }

  void stopStreaming() {
    _isStreaming = false;
    if (_waveId != null) {
      _socket.emit('stop-wave', {'waveId': _waveId, 'userId': 'emisor-123'});
    }
  }
}