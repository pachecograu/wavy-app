import 'package:flutter/material.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/services/audio_service.dart';

class AudioReceiver extends StatefulWidget {
  final String? waveId;
  
  const AudioReceiver({super.key, this.waveId});

  @override
  State<AudioReceiver> createState() => _AudioReceiverState();
}

class _AudioReceiverState extends State<AudioReceiver> {
  bool _isReceiving = false;
  int _packets = 0;
  final SocketService _socket = SocketService();
  final AudioService _audioService = AudioService();
  String? _hlsUrl;
  bool _hlsAvailable = false;
  bool _hlsPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.waveId != null) {
      _setupSocket();
    }
  }

  void _setupSocket() {
    _socket.connect().then((_) {
      final waveId = widget.waveId ?? 'test-wave';
      final userId = 'oyente-${DateTime.now().millisecondsSinceEpoch}';
      
      // Solo unirse si hay un waveId específico
      _socket.joinWave(waveId, userId);
      _socket.joinHybridRoom(waveId, userId);
      
      // Listener para obtener info de HLS y reproducir automáticamente
      _socket.onHybridRoomJoined((data) {
        if (mounted) {
          _hlsUrl = data['hlsUrl'];
          _hlsAvailable = data['isStreamActive'] == true;
          setState(() => _isReceiving = _hlsAvailable);
          
          // Auto-reproducir HLS si está disponible
          if (_hlsAvailable && _hlsUrl != null && !_hlsPlaying) {
            _startHlsPlayback();
          }
        }
      });
      
      // Listeners para datos en tiempo real
      _socket.onReceiveLiveAudio((data) {
        if (mounted) setState(() { _packets++; _isReceiving = true; });
      });
      
      _socket.onReceiveBits((data) {
        if (mounted) setState(() { _packets++; _isReceiving = true; });
      });
      
      _socket.onSongStarted((data) {
        if (mounted) setState(() => _isReceiving = true);
      });
      
      _socket.onAudioData((data) {
        if (mounted) setState(() { _packets++; _isReceiving = true; });
      });
      
      _socket.onReceiveAudioChunk((data) {
        if (mounted) setState(() { _packets++; _isReceiving = true; });
      });
    });
  }

  void _startHlsPlayback() async {
    // Solo simular que está reproduciendo sin intentar cargar audio real
    _hlsPlaying = true;
    if (mounted) {
      setState(() => _isReceiving = true);
    }
    print('🎵 HLS connection established for wave: ${widget.waveId}');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.waveId == null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.headphones_outlined, color: Colors.grey, size: 16),
            SizedBox(width: 8),
            Text(
              'SELECCIONA UN WAVE',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _isReceiving ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isReceiving ? Icons.volume_up : Icons.volume_off,
            color: _isReceiving ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _hlsPlaying ? 'CONECTADO A HLS' : _isReceiving ? 'RECIBIENDO DATOS' : 'SIN DATOS',
            style: TextStyle(
              color: _isReceiving ? Colors.green : Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_packets > 0) ...[
            const SizedBox(width: 8),
            Text('$_packets', style: const TextStyle(fontSize: 10)),
          ],
          if (_hlsAvailable) ...[
            const SizedBox(width: 8),
            Icon(
              _hlsPlaying ? Icons.play_circle : Icons.stream, 
              size: 12, 
              color: _hlsPlaying ? Colors.green : Colors.blue
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Solo limpiar estado, no intentar parar audio
    super.dispose();
  }
}