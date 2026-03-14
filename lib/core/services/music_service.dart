import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/track.dart';

class MusicService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static Track? _currentTrack;
  static List<Track> _s3Tracks = [];

  static Track? get currentTrack => _currentTrack;
  static AudioPlayer get audioPlayer => _audioPlayer;
  static List<Track> get s3Tracks => _s3Tracks;

  static Future<List<Track>> fetchTracks() async {
    try {
      final res = await http.get(Uri.parse('${AppConfig.apiUrl}/music'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _s3Tracks = (data['tracks'] as List).map((t) => Track(
          title: t['title'] ?? 'Unknown',
          artist: 'WAVY',
          url: t['url'],
          isCurrent: false,
          playedAt: DateTime.now(),
        )).toList();
      }
    } catch (e) {
      debugPrint('Error fetching S3 tracks: $e');
    }
    return _s3Tracks;
  }

  static Future<void> playTrack(Track track) async {
    try {
      if (track.url == null) return;
      await _audioPlayer.setUrl(track.url!);
      await _audioPlayer.play();
      _currentTrack = Track(
        title: track.title,
        artist: track.artist,
        url: track.url,
        isCurrent: true,
        playedAt: DateTime.now(),
      );
      debugPrint('Playing: ${track.title} from S3');
    } catch (e) {
      debugPrint('Error playing track: $e');
    }
  }

  static Future<void> stopMusic() async {
    await _audioPlayer.stop();
    _currentTrack = null;
  }

  static Future<void> pauseMusic() async => await _audioPlayer.pause();
  static Future<void> resumeMusic() async => await _audioPlayer.play();
}
