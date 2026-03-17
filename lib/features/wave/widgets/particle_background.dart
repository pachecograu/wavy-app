import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/wavy_theme.dart';
import '../../../core/services/music_service.dart';
import '../../../core/services/visualizer_service.dart';

class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  StreamSubscription? _visSub;
  bool _isPlaying = false;
  double _bass = 0.0;
  double _colorFreq = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 90),
    )..repeat();

    MusicService.audioPlayer.playerStateStream.listen((s) {
      if (!mounted) return;
      final playing = s.playing;
      if (playing && !_isPlaying) {
        VisualizerService.start();
      } else if (!playing && _isPlaying) {
        _bass = 0.0;
        _colorFreq = 0.0;
      }
      setState(() => _isPlaying = playing);
    });

    _visSub = VisualizerService.stream.listen((freq) {
      if (mounted) {
        _bass = VisualizerService.bass;
        _colorFreq = VisualizerService.colorFreq;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _visSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _SpherePainter(
            rotation: _controller.value * 2 * pi,
            bass: _bass,
            colorFreq: _colorFreq,
            isPlaying: _isPlaying,
          ),
        );
      },
    );
  }
}

// AudiShare: SphereGeometry(100, 30, 14).vertices
List<_SphereVertex> _buildVertices() {
  final rng = Random(42);
  final verts = <_SphereVertex>[];
  const wSeg = 30;
  const hSeg = 14;

  for (int y = 0; y <= hSeg; y++) {
    for (int x = 0; x <= wSeg; x++) {
      final u = x / wSeg;
      final v = y / hSeg;
      final theta = u * 2 * pi;
      final phi = v * pi;

      verts.add(_SphereVertex(
        hx: sin(phi) * cos(theta),
        hy: cos(phi),
        hz: sin(phi) * sin(theta),
        size: (x % 2 == 0) ? 1.0 : 2.0, // AudiShare: CircleGeometry(1) / CircleGeometry(2)
        cycle: rng.nextInt(100),          // AudiShare: randInt(0, 100)
        pace: 10 + rng.nextInt(20),       // AudiShare: randInt(10, 30)
      ));
    }
  }
  return verts;
}

final _verts = _buildVertices();

class _SpherePainter extends CustomPainter {
  final double rotation;
  final double bass;
  final double colorFreq;
  final bool isPlaying;

  static const double displaceRadius = 0.12;

  _SpherePainter({
    required this.rotation,
    required this.bass,
    required this.colorFreq,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseR = size.height * 0.45;
    final cx = size.width + baseR * 0.1;
    final cy = size.height * 0.5;

    final zoom = 1.0 + bass * 0.2;

    // Polo de arriba inclinado hacia adelante (hacia el viewer), polos alineados, gira sobre su eje
    const tiltX = -0.3;
    // AudiShare: rotation.y -= 0.003 → one full rotation in ~35s
    final rotY = rotation;

    final hue = isPlaying ? colorFreq : 0.0;

    final paint = Paint();

    for (final v in _verts) {
      final y1 = v.hy * cos(tiltX) - v.hz * sin(tiltX);
      final z1 = v.hy * sin(tiltX) + v.hz * cos(tiltX);

      final x2 = v.hx * cos(rotY) + z1 * sin(rotY);
      final z2 = -v.hx * sin(rotY) + z1 * cos(rotY);
      final y2 = y1;

      // AudiShare: translateZ(bass * sin(cycle/pace) * radius)
      final cycle = v.cycle + (rotation * 60).toInt();
      final displace = bass * sin(cycle / v.pace) * displaceRadius;

      final r = baseR * (1.0 + displace) * zoom;

      final sx = cx + x2 * r;
      final sy = cy + y2 * r;
      final depth = (z2 + 1.0) / 2.0;

      final alpha = (0.1 + 0.9 * depth).clamp(0.0, 1.0);
      final dotSize = v.size * (0.3 + 0.7 * depth);

      Color c;
      if (isPlaying) {
        c = HSLColor.fromAHSL(1.0, (hue * 360) % 360, 0.6, 0.35 + 0.35 * depth).toColor();
      } else {
        c = WavyTheme.textSecondary;
      }

      paint.color = c.withValues(alpha: alpha * (isPlaying ? 0.75 : 0.12));
      canvas.drawCircle(Offset(sx, sy), dotSize, paint);
    }
  }

  @override
  bool shouldRepaint(_SpherePainter old) =>
      rotation != old.rotation || bass != old.bass || colorFreq != old.colorFreq || isPlaying != old.isPlaying;
}

class _SphereVertex {
  final double hx, hy, hz;
  final double size;
  final int cycle;
  final int pace;

  const _SphereVertex({
    required this.hx,
    required this.hy,
    required this.hz,
    required this.size,
    required this.cycle,
    required this.pace,
  });
}
