import 'package:flutter/material.dart';
import '../widgets/hybrid_audio_player.dart';

class HybridTestPage extends StatelessWidget {
  const HybridTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WAVY Hybrid Test'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎯 Arquitectura Híbrida WAVY',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('🎵 Música → HLS (HTTP Streaming)'),
                    Text('🎙️ Voz → WebRTC (LiveKit)'),
                    Text('💬 Chat → Socket.IO'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HybridAudioPlayer(
                      roomId: 'test-room-1',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              child: const Text(
                'Unirse a Sala de Prueba',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 Instrucciones:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Asegúrate de que el backend esté corriendo'),
                    Text('2. La música se reproduce automáticamente (HLS)'),
                    Text('3. Presiona "Pedir Mic" para activar voz (WebRTC)'),
                    Text('4. Ajusta el volumen de música independientemente'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}