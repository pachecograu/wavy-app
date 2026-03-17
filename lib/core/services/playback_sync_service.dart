import 'dart:async';
import 'package:flutter/foundation.dart';
import '../socket/socket_service.dart';
import 'music_service.dart';

class PlaybackSyncService {
  static final SocketService _socket = SocketService();
  static String? _waveId;
  static bool _isDJ = false;
  static bool _listening = false;
  static Timer? _syncTimer;

  static void startAsDJ(String waveId) {
    _waveId = waveId;
    _isDJ = true;
    _syncTimer?.cancel();

    // Periodically sync position so late-joining listeners catch up
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _emitSync();
    });

    // Listen to DJ's player state changes
    MusicService.audioPlayer.playerStateStream.listen((state) {
      if (!_isDJ || _waveId == null) return;
      _socket.emit('playback-sync', {
        'waveId': _waveId,
        'action': state.playing ? 'play' : 'pause',
        'currentTime': MusicService.audioPlayer.position.inMilliseconds,
      });
    });
  }

  static void emitSeek() {
    if (!_isDJ || _waveId == null) return;
    _socket.emit('playback-sync', {
      'waveId': _waveId,
      'action': 'seek',
      'currentTime': MusicService.audioPlayer.position.inMilliseconds,
    });
  }

  static void startAsListener(String waveId) {
    _waveId = waveId;
    _isDJ = false;
    if (_listening) return;
    _listening = true;

    _socket.on('sync-playback', (data) {
      try {
        final action = data['action']?.toString();
        final currentTimeMs = (data['currentTime'] as num?)?.toInt() ?? 0;
        final position = Duration(milliseconds: currentTimeMs);

        debugPrint('🔄 Sync: $action at ${position.inSeconds}s');

        switch (action) {
          case 'play':
            MusicService.audioPlayer.seek(position);
            MusicService.audioPlayer.play();
            break;
          case 'pause':
            MusicService.audioPlayer.pause();
            break;
          case 'seek':
            MusicService.audioPlayer.seek(position);
            break;
        }
      } catch (e) {
        debugPrint('Error in sync-playback: $e');
      }
    });
  }

  static void _emitSync() {
    if (!_isDJ || _waveId == null) return;
    _socket.emit('playback-sync', {
      'waveId': _waveId,
      'action': MusicService.audioPlayer.playing ? 'play' : 'pause',
      'currentTime': MusicService.audioPlayer.position.inMilliseconds,
    });
  }

  static void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _waveId = null;
    _isDJ = false;
    _listening = false;
    _socket.off('sync-playback');
  }
}
