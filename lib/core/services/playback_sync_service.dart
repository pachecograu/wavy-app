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
  static const int _driftThresholdMs = 350;

  static void startAsDJ(String waveId) {
    _waveId = waveId;
    _isDJ = true;
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (_) => _emitPosition());
    _emitPosition();
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

    _socket.on('playback-state', (data) {
      try {
        final action = data['action']?.toString();
        final ms = (data['currentTime'] as num?)?.toInt() ?? 0;
        final sentAt = (data['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
        final now = DateTime.now().millisecondsSinceEpoch;
        final compensatedMs = action == 'play' || action == 'position'
            ? ms + (now - sentAt).clamp(0, 1500)
            : ms;

        _applySync(action, compensatedMs);
      } catch (e) {
        debugPrint('Error in playback-state: $e');
      }
    });

    _socket.on('sync-playback', (data) {
      try {
        final action = data['action']?.toString();
        final ms = (data['currentTime'] as num?)?.toInt() ?? 0;
        final sentAt = (data['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
        final now = DateTime.now().millisecondsSinceEpoch;
        final compensatedMs = action == 'play' || action == 'position'
            ? ms + (now - sentAt).clamp(0, 1500)
            : ms;

        _applySync(action, compensatedMs);
      } catch (e) {
        debugPrint('Error in sync-playback: $e');
      }
    });

    _socket.emit('request-playback-state', {'waveId': waveId});
  }

  static void _applySync(String? action, int targetMs) {
    switch (action) {
      case 'play':
        _seekIfNeeded(targetMs);
        MusicService.audioPlayer.play();
        break;
      case 'pause':
        MusicService.audioPlayer.pause();
        break;
      case 'seek':
        MusicService.audioPlayer.seek(Duration(milliseconds: targetMs));
        break;
      case 'position':
        if (!MusicService.audioPlayer.playing) {
          _seekIfNeeded(targetMs);
          MusicService.audioPlayer.play();
        } else {
          _seekIfNeeded(targetMs);
        }
        break;
    }
  }

  static void _seekIfNeeded(int targetMs) {
    final currentMs = MusicService.audioPlayer.position.inMilliseconds;
    if ((currentMs - targetMs).abs() > _driftThresholdMs) {
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
    _socket.off('playback-state');
  }
}
