import 'package:flutter/material.dart';
import '../../../core/services/socket_service.dart';

class SimpleAudioReceiver extends StatefulWidget {
  const SimpleAudioReceiver({super.key});

  @override
  State<SimpleAudioReceiver> createState() => _SimpleAudioReceiverState();
}

class _SimpleAudioReceiverState extends State<SimpleAudioReceiver> {
  bool _isReceiving = false;
  int _packetsReceived = 0;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    try {
      final socketService = SocketService();
      
      // Conectar y unirse silenciosamente a la wave
      socketService.connect().then((_) {
        final waveId = 'test-wave';
        final userId = 'oyente-${DateTime.now().millisecondsSinceEpoch}';
        
        // Solo unirse a la wave, sin user-connected
        socketService.joinWave(waveId, userId);
      }).catchError((e) {
        print('⚠️ Error conectando oyente: $e');
      });
      
      // Solo listeners para recibir audio
      socketService.onSongStarted((data) {
        try {
          if (mounted) {
            setState(() => _isReceiving = true);
          }
        } catch (e) {
          print('❌ Error procesando song-started: $e');
        }
      });

      socketService.onReceiveLiveAudio((data) {
        try {
          if (mounted) {
            setState(() {
              _packetsReceived++;
              _isReceiving = true;
            });
          }
        } catch (e) {
          print('❌ Error procesando live-audio: $e');
        }
      });

      socketService.onReceiveBits((data) {
        try {
          if (mounted) {
            setState(() {
              _packetsReceived++;
              _isReceiving = true;
            });
          }
        } catch (e) {
          print('❌ Error procesando bits: $e');
        }
      });

      socketService.onAudioData((data) {
        try {
          if (mounted) {
            setState(() {
              _packetsReceived++;
              _isReceiving = true;
            });
          }
        } catch (e) {
          print('❌ Error procesando audio-data: $e');
        }
      });

      socketService.onReceiveAudioChunk((data) {
        try {
          if (mounted) {
            setState(() {
              _packetsReceived++;
              _isReceiving = true;
            });
          }
        } catch (e) {
          print('❌ Error procesando audio-chunk: $e');
        }
      });

    } catch (e) {
      print('❌ Error en oyente: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _isReceiving ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isReceiving ? Icons.volume_up : Icons.volume_off,
            color: _isReceiving ? Colors.green : Colors.grey,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            _isReceiving ? 'AUDIO ON' : 'NO AUDIO',
            style: TextStyle(
              color: _isReceiving ? Colors.green : Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_packetsReceived > 0) ...[
            const SizedBox(width: 6),
            Text(
              '$_packetsReceived',
              style: const TextStyle(fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }
}