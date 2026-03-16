import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../models/track.dart';

class MusicService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static Track? _currentTrack;
  static List<Track> _s3Tracks = [];

  static const String _bucketUrl =
      'https://wavy-music-372714114281.s3.us-east-1.amazonaws.com';

  static Track? get currentTrack => _currentTrack;
  static AudioPlayer get audioPlayer => _audioPlayer;
  static List<Track> get s3Tracks => _s3Tracks;

  static Future<List<Track>> fetchTracks() async {
    try {
      final res = await http.get(Uri.parse('$_bucketUrl/'));
      if (res.statusCode == 200) {
        final doc = xml.XmlDocument.parse(res.body);
        final ns = doc.rootElement.name.namespaceUri;

        _s3Tracks = doc.rootElement
            .findAllElements('Contents', namespace: ns)
            .map((node) {
              final key = node.getElement('Key', namespace: ns)?.innerText ?? '';
              if (key.isEmpty) return null;
              final title = Uri.decodeComponent(key.split('/').last)
                  .replaceAll(RegExp(r'\.[^.]+$'), '');
              return Track(
                title: title,
                artist: 'WAVY',
                url: '$_bucketUrl/$key',
                isCurrent: false,
                playedAt: DateTime.now(),
              );
            })
            .whereType<Track>()
            .where((t) => t.url!.toLowerCase().endsWith('.mp3') ||
                t.url!.toLowerCase().endsWith('.aac') ||
                t.url!.toLowerCase().endsWith('.m4a') ||
                t.url!.toLowerCase().endsWith('.wav') ||
                t.url!.toLowerCase().endsWith('.ogg'))
            .toList();
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
