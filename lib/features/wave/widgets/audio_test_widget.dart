import 'package:flutter/material.dart';
import '../../../core/services/simple_audio_emitter.dart';
import '../../../core/services/hybrid_audio_service.dart';
import 'simple_audio_receiver.dart';
import 'audio_receiver.dart';

class AudioTestWidget extends StatefulWidget {
  const AudioTestWidget({super.key});

  @override
  State<AudioTestWidget> createState() => _AudioTestWidgetState();
}

class _AudioTestWidgetState extends State<AudioTestWidget> {
  final SimpleAudioEmitter _emitter = SimpleAudioEmitter();
  final HybridAudioService _hybridService = HybridAudioService();
  bool _isEmitting = false;
  bool _isHybridActive = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Test de Audio en Tiempo Real + HLS',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          
          // Emisor Híbrido (HLS + Bits)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('EMISOR HÍBRIDO (HLS + Bits)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _isHybridActive ? _stopHybrid : _startHybrid,
                    child: Text(_isHybridActive ? 'PARAR HLS' : 'INICIAR HLS'),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isHybridActive ? Colors.blue.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isHybridActive ? Icons.stream : Icons.stream_outlined,
                          color: _isHybridActive ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isHybridActive ? 'HLS ACTIVO' : 'HLS DETENIDO',
                          style: TextStyle(
                            color: _isHybridActive ? Colors.blue : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 10),
          
          // Emisor Simple (Solo Bits)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('EMISOR SIMPLE (Solo Bits)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _isEmitting ? _stopEmitting : _startEmitting,
                    child: Text(_isEmitting ? 'PARAR BITS' : 'INICIAR BITS'),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isEmitting ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isEmitting ? Icons.radio : Icons.radio_button_off,
                          color: _isEmitting ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isEmitting ? 'BITS ACTIVOS' : 'BITS DETENIDOS',
                          style: TextStyle(
                            color: _isEmitting ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Receptores
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('RECEPTOR HÍBRIDO (HLS + Bits)', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  AudioReceiver(),
                  SizedBox(height: 15),
                  Text('RECEPTOR SIMPLE (Solo Bits)', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  SimpleAudioReceiver(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startHybrid() async {
    try {
      await _hybridService.joinRoom('test-wave', 'emisor-hybrid', isHost: true);
      setState(() => _isHybridActive = true);
      print('🌊 HLS híbrido iniciado');
    } catch (e) {
      print('❌ Error iniciando híbrido: $e');
    }
  }

  void _stopHybrid() {
    try {
      _hybridService.leaveRoom();
      setState(() => _isHybridActive = false);
      print('🚫 HLS híbrido detenido');
    } catch (e) {
      print('❌ Error deteniendo híbrido: $e');
    }
  }

  void _startEmitting() async {
    try {
      await _emitter.startStreaming();
      setState(() => _isEmitting = true);
      print('🎵 Bits simples iniciados');
    } catch (e) {
      print('❌ Error iniciando bits: $e');
    }
  }

  void _stopEmitting() {
    try {
      _emitter.stopStreaming();
      setState(() => _isEmitting = false);
      print('🚫 Bits simples detenidos');
    } catch (e) {
      print('❌ Error deteniendo bits: $e');
    }
  }

  @override
  void dispose() {
    if (_isEmitting) {
      _emitter.stopStreaming();
    }
    if (_isHybridActive) {
      _hybridService.leaveRoom();
    }
    super.dispose();
  }
}