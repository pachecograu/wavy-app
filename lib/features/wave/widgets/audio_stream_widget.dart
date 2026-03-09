import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/wavy_theme.dart';
import '../providers/wave_provider.dart';
import 'audio_receiver.dart';

class AudioStreamWidget extends StatefulWidget {
  const AudioStreamWidget({super.key});

  @override
  State<AudioStreamWidget> createState() => _AudioStreamWidgetState();
}

class _AudioStreamWidgetState extends State<AudioStreamWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<WaveProvider>(
      builder: (context, waveProvider, child) {
        if (waveProvider.currentWave == null || waveProvider.isOwner) {
          return const SizedBox.shrink();
        }

        return Flexible(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: WavyTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: WavyTheme.primaryRed.withOpacity(0.3),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Receptor de audio simple
                const AudioReceiver(),
                const SizedBox(height: 16),
                Text(
                  'DJ: ${waveProvider.currentWave?.djName ?? 'DJ desconocido'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: WavyTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}