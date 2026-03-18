import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../models/track.dart';
import 'wavy_audio_handler.dart';

class MusicService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static WavyAudioHandler? _handler;
  static Track? _currentTrack;
  static List<Track> _s3Tracks = [];
  static Future<List<Track>>? _fetchFuture;

  static const String _bucketUrl =
      'https://wavy-music-372714114281.s3.us-east-1.amazonaws.com';

  static Track? get currentTrack => _currentTrack;
  static AudioPlayer get audioPlayer => _audioPlayer;
  static List<Track> get s3Tracks => _s3Tracks;

  static void setHandler(WavyAudioHandler handler) {
    _handler = handler;
  }

  static WavyAudioHandler? get handler => _handler;

  static String _percentEncodeBytes(List<int> bytes) {
    final sb = StringBuffer();
    const unreserved = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~';
    for (final b in bytes) {
      if (b == 0x2F) {
        sb.write('/');
      } else if (unreserved.codeUnitAt(0) <= b && b <= 0x7E && unreserved.contains(String.fromCharCode(b))) {
        sb.write(String.fromCharCode(b));
      } else {
        sb.write('%${b.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return sb.toString();
  }

  static Future<List<Track>> fetchTracks({bool forceRefresh = false}) {
    if (!forceRefresh && _fetchFuture != null) return _fetchFuture!;
    _fetchFuture = _doFetchTracks();
    return _fetchFuture!;
  }

  static Future<List<Track>> _doFetchTracks() async {
    try {
      debugPrint('🎵 Fetching S3 tracks from: $_bucketUrl/');
      final res = await http.get(Uri.parse('$_bucketUrl/')).timeout(const Duration(seconds: 10));
      debugPrint('🎵 S3 response status: ${res.statusCode}');

      if (res.statusCode != 200) {
        throw Exception('S3 respondió con status ${res.statusCode}');
      }

      final bodyBytes = res.bodyBytes;
      final bodyStr = utf8.decode(bodyBytes);
      final doc = xml.XmlDocument.parse(bodyStr);
      final ns = doc.rootElement.name.namespaceUri;

      final audioExtensions = ['.mp3', '.aac', '.m4a', '.wav', '.ogg'];

      final contents = doc.rootElement.findAllElements('Contents', namespace: ns).toList();
      final tracks = <Track>[];

      for (final node in contents) {
        final key = node.getElement('Key', namespace: ns)?.innerText ?? '';
        if (key.isEmpty) continue;
        final lower = key.toLowerCase();
        if (!audioExtensions.any((ext) => lower.endsWith(ext))) continue;

        final fileName = key.split('/').last;
        final title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

        final encodedPath = _buildS3Url(key, bodyBytes);
        final url = '$_bucketUrl/$encodedPath';
        debugPrint('🎵 Track: $title → $url');

        tracks.add(Track(
          title: title,
          artist: 'WAVY',
          url: url,
          isCurrent: false,
          playedAt: DateTime.now(),
        ));
      }

      _s3Tracks = tracks;
      debugPrint('🎵 Found ${_s3Tracks.length} tracks in S3');
      return _s3Tracks;
    } catch (e) {
      debugPrint('❌ Error fetching S3 tracks: $e');
      rethrow;
    }
  }

  static String _buildS3Url(String key, List<int> bodyBytes) {
    final keyTag = utf8.encode('<Key>');
    final endTag = utf8.encode('</Key>');

    int searchFrom = 0;
    while (searchFrom < bodyBytes.length) {
      int tagStart = _indexOf(bodyBytes, keyTag, searchFrom);
      if (tagStart == -1) break;

      int valueStart = tagStart + keyTag.length;
      int tagEnd = _indexOf(bodyBytes, endTag, valueStart);
      if (tagEnd == -1) break;

      final rawKeyBytes = bodyBytes.sublist(valueStart, tagEnd);
      final decodedKey = utf8.decode(rawKeyBytes, allowMalformed: true);

      if (decodedKey == key) {
        return _percentEncodeBytes(rawKeyBytes);
      }

      searchFrom = tagEnd + endTag.length;
    }

    return key.split('/').map((s) => Uri.encodeComponent(s)).join('/');
  }

  static int _indexOf(List<int> haystack, List<int> needle, int start) {
    for (int i = start; i <= haystack.length - needle.length; i++) {
      bool match = true;
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  static Future<void> playTrack(Track track) async {
    if (track.url == null) return;
    try {
      _currentTrack = Track(
        title: track.title,
        artist: track.artist,
        url: track.url,
        isCurrent: true,
        playedAt: DateTime.now(),
      );
      _handler?.updateNowPlaying(track.title, track.artist);
      await _audioPlayer.setUrl(track.url!);
      await _audioPlayer.play();
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
