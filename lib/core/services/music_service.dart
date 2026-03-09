import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';

class MusicService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static Track? _currentTrack;
  
  static Track? get currentTrack => _currentTrack;
  static AudioPlayer get audioPlayer => _audioPlayer;
  
  static Future<List<String>> getLocalMusicFiles() async {
    try {
      // Lista manual de archivos conocidos
      const musicFiles = [
        'assets/music/deadpool.mpeg',
      ];
      
      List<String> availableFiles = [];
      for (String file in musicFiles) {
        try {
          await rootBundle.load(file);
          availableFiles.add(file);
        } catch (e) {
          // Archivo no existe, continuar
        }
      }
      
      return availableFiles;
    } catch (e) {
      return [];
    }
  }
  
  static Future<void> playLocalMusic(String assetPath, String title, String artist, {bool isStreaming = false}) async {
    try {
      await _audioPlayer.setAsset(assetPath);
      await _audioPlayer.play();
      _currentTrack = Track(
        title: title,
        artist: artist,
        isCurrent: true,
        playedAt: DateTime.now(),
      );
      
      print('Playing music: $title by $artist');
    } catch (e) {
      print('Error playing music: $e');
    }
  }
  

  
  static Future<void> stopMusicAndStreaming() async {
    await _audioPlayer.stop();
    _currentTrack = null;
  }
  
  static Future<void> stopMusic() async {
    await _audioPlayer.stop();
    _currentTrack = null;
  }
  
  static Future<void> pauseMusic() async {
    await _audioPlayer.pause();
  }
  
  static Future<void> resumeMusic() async {
    await _audioPlayer.play();
  }
}