import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'music_service.dart';

class VisualizerService {
  static const _channel = EventChannel('wavy/visualizer');
  static StreamSubscription? _nativeSub;
  static Timer? _fallbackTimer;
  static bool _hasNativeData = false;

  static List<int> _freqData = List.filled(32, 0);
  static final _controller = StreamController<List<int>>.broadcast();

  static List<int> get freqData => _freqData;
  static Stream<List<int>> get stream => _controller.stream;

  static double get bass => (_freqData.length > 1 ? _freqData[1] : 0) / 255.0;
  static double get colorFreq => (_freqData.length > 16 ? _freqData[16] : 0) / 255.0;

  static void start() {
    if (_nativeSub != null) return;

    // Try native Visualizer
    _nativeSub = _channel.receiveBroadcastStream().listen(
      (data) {
        if (data is List) {
          _hasNativeData = true;
          _fallbackTimer?.cancel();
          _fallbackTimer = null;
          _freqData = data.cast<int>();
          _controller.add(_freqData);
        }
      },
      onError: (_) {
        _startFallback();
      },
    );

    // Start fallback after 2s if no native data arrives
    Future.delayed(const Duration(seconds: 2), () {
      if (!_hasNativeData) _startFallback();
    });
  }

  static void _startFallback() {
    if (_fallbackTimer != null) return;
    final rng = Random();

    _fallbackTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final playing = MusicService.audioPlayer.playing;
      if (!playing) {
        _freqData = List.filled(32, 0);
        _controller.add(_freqData);
        return;
      }

      // Generate pseudo-FFT that reacts to playback time
      final ms = MusicService.audioPlayer.position.inMilliseconds.toDouble();
      _freqData = List.generate(32, (i) {
        // Lower frequencies (bass) have more energy
        final baseEnergy = 180 - (i * 4).clamp(0, 150);
        // Oscillate at different rates per bin to simulate real spectrum
        final wave = sin(ms / (200 + i * 30)) * 0.5 + 0.5;
        // Add randomness for organic feel
        final noise = rng.nextDouble() * 30;
        return (baseEnergy * wave + noise).clamp(0, 255).toInt();
      });
      _controller.add(_freqData);
    });
  }

  static void stop() {
    _nativeSub?.cancel();
    _nativeSub = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _hasNativeData = false;
    _freqData = List.filled(32, 0);
  }
}
