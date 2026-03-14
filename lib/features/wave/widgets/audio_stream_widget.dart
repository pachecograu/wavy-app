import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/wavy_theme.dart';
import '../providers/wave_provider.dart';
import 'audio_receiver.dart';

class AudioStreamWidget extends StatelessWidget {
  const AudioStreamWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WaveProvider>(
      builder: (context, wp, _) {
        if (wp.currentWave == null || wp.isOwner) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WavyTheme.cardBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: WavyTheme.borderColor, width: 2),
          ),
          child: const AudioReceiver(),
        );
      },
    );
  }
}
