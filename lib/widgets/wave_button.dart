import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/wave_service.dart';
import '../providers/wave_provider.dart';

class WaveButton extends StatelessWidget {
  final Wave wave;
  
  const WaveButton({super.key, required this.wave});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: () {
          context.read<WaveProvider>().joinWave(wave.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Joined ${wave.name}')),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: const Color(0xFF8B0000).withOpacity(0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFFDC143C),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wave.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${wave.listenersCount} listeners • ${wave.djName}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.play_arrow,
              color: Color(0xFFDC143C),
            ),
          ],
        ),
      ),
    );
  }
}