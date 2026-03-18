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
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) => _emitPosition());
  }

  static void emitPlayPause() {
    if (!_isDJ || _waveId == null) return;
    _socket.emit('playback-sync', {
      'waveId': _waveId,
      'action': MusicService.audioPlayer.playing ? 'play' : 'pause',
      'currentTime': MusicService.audioPlayer.position.inMilliseconds,
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
        final ms = (data['currentTime'] as num?)?.toInt() ?? 0;

        switch (action) {
          case 'play':
            _seekIfNeeded(ms);
            MusicService.audioPlayer.play();
            break;
          case 'pause':
            MusicService.audioPlayer.pause();
            break;
          case 'seek':
            MusicService.audioPlayer.seek(Duration(milliseconds: ms));
            break;
          case 'position':
            if (!MusicService.audioPlayer.playing) {
              // DJ is playing but we're paused — resume
              _seekIfNeeded(ms);
              MusicService.audioPlayer.play();
            } else {
              _seekIfNeeded(ms);
            }
            break;
        }
      } catch (e) {
        debugPrint('Error in sync-playback: $e');
      }
    });
  }

  static void _seekIfNeeded(int targetMs) {
    final currentMs = MusicService.audioPlayer.position.inMilliseconds;
    if ((currentMs - targetMs).abs() > 2000) {
      MusicService.audioPlayer.seek(Duration(milliseconds: targetMs));
    }
  }

  static void _emitPosition() {
    if (!_isDJ || _waveId == null) return;
    _socket.emit('playback-sync', {
      'waveId': _waveId,
      'action': MusicService.audioPlayer.playing ? 'position' : 'pause',
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
