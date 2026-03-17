import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/models/track.dart';
import '../../../core/services/music_service.dart';
class TrackProvider with ChangeNotifier {
  final SocketService _socketService = SocketService();
  
  Track? _currentTrack;
  List<Track> _playedTracks = [];
  String? _currentWaveId;
  
  Track? get currentTrack => _currentTrack;
  List<Track> get playedTracks => _playedTracks;
  
  bool _listenersRegistered = false;

  void initialize(String waveId) {
    if (_currentWaveId == waveId) {
      return;
    }
    _currentWaveId = waveId;
    if (!_listenersRegistered) {
      _listenersRegistered = true;
      _setupSocketListeners();
    }
    _loadWaveTracks();
  }
  
  void _setupSocketListeners() {
    _socketService.on('current-track-updated', (data) {
      try {
        final jsonString = jsonEncode(data);
        final trackData = jsonDecode(jsonString) as Map<String, dynamic>;
        
        final url = trackData['url']?.toString();
        
        _currentTrack = Track(
          title: trackData['title']?.toString() ?? '',
          artist: trackData['artist']?.toString() ?? '',
          url: url,
          duration: trackData['duration'] as int?,
          isCurrent: true,
          playedAt: DateTime.tryParse(trackData['playedAt']?.toString() ?? '') ?? DateTime.now(),
        );
        
        // Add to played tracks if not already there
        if (!_playedTracks.any((t) => 
            t.title == _currentTrack!.title && 
            t.artist == _currentTrack!.artist)) {
          _playedTracks = List<Track>.from(_playedTracks)..insert(0, _currentTrack!);
        }
        
        // Auto-play for listeners: if URL is present, play from S3
        if (url != null && url.isNotEmpty) {
          MusicService.playTrack(_currentTrack!);
        }
        
        notifyListeners();
      } catch (e) {
        debugPrint('Error parsing current-track-updated data: $e');
      }
    });
    
    _socketService.on('wave-tracks', (data) {
      try {
        final jsonString = jsonEncode(data);
        final dataMap = jsonDecode(jsonString) as Map<String, dynamic>;
        
        if (dataMap['waveId'] == _currentWaveId) {
          final tracksList = dataMap['tracks'] as List? ?? [];
          final tracks = tracksList
              .map((trackData) => Track.fromJson(trackData as Map<String, dynamic>))
              .toList();
          
          _currentTrack = tracks.isNotEmpty 
              ? tracks.firstWhere(
                  (track) => track.isCurrent,
                  orElse: () => tracks.first,
                )
              : null;
          
          _playedTracks = tracks;
          
          // Auto-play current track for listeners joining mid-session
          if (_currentTrack?.url != null && _currentTrack!.url!.isNotEmpty) {
            MusicService.playTrack(_currentTrack!);
          }
          
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error parsing wave-tracks data: $e');
      }
    });
  }
  
  void _loadWaveTracks() {
    if (_currentWaveId != null) {
      _socketService.emit('get-wave-tracks', {
        'waveId': _currentWaveId,
      });
    }
  }
  
  void updateCurrentTrack(String title, String artist, {int? duration, String? url}) {
    if (_currentWaveId != null) {
      _socketService.emit('update-current-track', {
        'waveId': _currentWaveId,
        'title': title,
        'artist': artist,
        'duration': duration,
        'url': url,
      });
      _socketService.emit('log-action', {
        'action': 'TRACK_CHANGED',
        'waveId': _currentWaveId,
        'title': title,
        'artist': artist,
        'duration': duration
      });
    }
  }
  
  void clearTracks() {
    _currentTrack = null;
    _playedTracks.clear();
    notifyListeners();
  }
}