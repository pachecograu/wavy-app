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
      print('🎵 Starting HLS stream: $hlsUrl');
      
      await _musicPlayer.setUrl(hlsUrl);
      await _musicPlayer.play();
      _isMusicPlaying = true;
      
      print('🎵 HLS stream started successfully');
    } catch (e) {
      print('❌ Error starting music stream: $e');
      // Fallback: try with test audio
      try {
        await _musicPlayer.setAsset('assets/music/test.mp3');
        await _musicPlayer.play();
        _isMusicPlaying = true;
        print('🎵 Fallback audio started');
      } catch (fallbackError) {
        print('❌ Fallback also failed: $fallbackError');
        throw Exception('Error starting music stream: $e');
      }
    }
  }

  Future<void> stopMusicStream() async {
    await _musicPlayer.stop();
    _isMusicPlaying = false;
    print('🎵 Music stream stopped');
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