import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/wavy_theme.dart';
import '../providers/track_provider.dart';

class TrackListWidget extends StatelessWidget {
  const TrackListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackProvider>(
      builder: (context, trackProvider, child) {
        if (trackProvider.playedTracks.isEmpty) {
          return const Center(
            child: Text(
              'No hay tracks reproducidos',
              style: TextStyle(
                color: WavyTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: trackProvider.playedTracks.length,
          itemBuilder: (context, index) {
            final track = trackProvider.playedTracks[index];
            return ListTile(
              leading: Icon(
                track.isCurrent ? Icons.play_arrow : Icons.music_note,
                color: track.isCurrent ? WavyTheme.primaryRed : WavyTheme.textSecondary,
              ),
              title: Text(
                track.title,
                style: TextStyle(
                  fontWeight: track.isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: track.isCurrent ? WavyTheme.primaryRed : WavyTheme.textPrimary,
                ),
              ),
              subtitle: Text(
                track.artist,
                style: const TextStyle(
                  color: WavyTheme.textSecondary,
                ),
              ),
            );
          },
        );
      },
    );
  }
}