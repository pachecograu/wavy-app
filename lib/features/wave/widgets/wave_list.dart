import 'package:flutter/material.dart';
import '../../../core/theme/wavy_theme.dart';
import '../../../core/models/wave.dart';

class WaveList extends StatelessWidget {
  final List<Wave> waves;
  final Function(Wave) onWaveTap;
  
  const WaveList({
    super.key, 
    required this.waves, 
    required this.onWaveTap,
  });

  @override
  Widget build(BuildContext context) {
    if (waves.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.radio,
              size: 64,
              color: WavyTheme.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'No waves online',
              style: TextStyle(
                color: WavyTheme.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: waves.length,
      itemBuilder: (context, index) {
        final wave = waves[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: WavyTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onWaveTap(wave),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: WavyTheme.primaryRed.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: wave.isOnline ? WavyTheme.accentRed : WavyTheme.textSecondary,
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
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          Text(
                            '${wave.djName} • ${wave.listenersCount} listeners',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.play_arrow,
                      color: WavyTheme.accentRed,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}