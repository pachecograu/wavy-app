import 'package:flutter/material.dart';
import '../../../core/socket/socket_service.dart';

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

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _socket.on('receive-live-audio', (data) {
      if (mounted) setState(() { _packets++; _isReceiving = true; });
    });

    _socket.on('receive-bits', (data) {
      if (mounted) setState(() { _packets++; _isReceiving = true; });
    });

    _socket.on('song-started', (data) {
      if (mounted) setState(() => _isReceiving = true);
    });

    _socket.on('audio-data', (data) {
      if (mounted) setState(() { _packets++; _isReceiving = true; });
    });

    _socket.on('receive-audio-chunk', (data) {
      if (mounted) setState(() { _packets++; _isReceiving = true; });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.waveId == null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.headphones_outlined, color: Colors.grey, size: 16),
            SizedBox(width: 8),
            Text('SELECCIONA UN WAVE',
                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _isReceiving ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
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
            _isReceiving ? 'RECIBIENDO AUDIO' : 'SIN DATOS',
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
        ],
      ),
    );
  }
}
