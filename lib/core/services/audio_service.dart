import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../config/app_config.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _isMusicPlaying = false;

  Future<void> startMusicStream(String roomId) async {
    try {
      final hlsUrl = '${AppConfig.hlsStreamUrl}/$roomId/index.m3u8';
      debugPrint('🎵 Starting HLS stream: $hlsUrl');

      await _musicPlayer.setUrl(hlsUrl);
      await _musicPlayer.play();
      _isMusicPlaying = true;

      debugPrint('🎵 HLS stream started successfully');
    } catch (e) {
      debugPrint('❌ Error starting music stream: $e');
      try {
        await _musicPlayer.setAsset('assets/music/test.mp3');
        await _musicPlayer.play();
        _isMusicPlaying = true;
        debugPrint('🎵 Fallback audio started');
      } catch (fallbackError) {
        debugPrint('❌ Fallback also failed: $fallbackError');
        throw Exception('Error starting music stream: $e');
      }
    }
  }

  Future<void> stopMusicStream() async {
    await _musicPlayer.stop();
    _isMusicPlaying = false;
    debugPrint('🎵 Music stream stopped');
  }

  Future<void> setMusicVolume(double volume) async {
    await _musicPlayer.setVolume(volume);
  }

  bool get isMusicPlaying => _isMusicPlaying;

  Stream<Duration> get positionStream => _musicPlayer.positionStream;
  Stream<PlayerState> get playerStateStream => _musicPlayer.playerStateStream;

  void dispose() {
    _musicPlayer.dispose();
  }
}
