import 'package:flutter/material.dart';
import '../../../core/theme/wavy_theme.dart';
import '../../../core/models/wave.dart';

class WaveInfoCard extends StatelessWidget {
  final Wave wave;
  
  const WaveInfoCard({super.key, required this.wave});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WavyTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: WavyTheme.primaryRed.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: wave.isOnline ? WavyTheme.accentRed : WavyTheme.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(wave.isOnline ? 'ONLINE' : 'OFFLINE'),
              const Spacer(),
              Text('👥 ${wave.listenersCount} listeners'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            wave.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(
            wave.djName,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}