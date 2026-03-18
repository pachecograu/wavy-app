import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/wavy_theme.dart';
import '../../wave/screens/wave_home_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: WavyTheme.darkBackground,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.headphones, size: 180, color: WavyTheme.primaryRed)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .shimmer(duration: 7000.ms, color: WavyTheme.primaryRed.withValues(alpha: 0.3))
                  .flipH(begin: 0, end: 1, duration: 7000.ms),
              const SizedBox(height: 12),
              Text(
                'WAVY',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: WavyTheme.primaryRed,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 4),
              Text(
                'Live Audio Social Platform',
                style: TextStyle(color: WavyTheme.textSecondary.withValues(alpha: 0.6), fontSize: 12),
              ).animate().fadeIn(delay: 300.ms, duration: 600.ms),
              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigate(context, UserRole.oyente),
                    icon: const Icon(Icons.headphones, size: 18),
                    label: const Text('MODO OYENTE', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ).animate().slideY(begin: 1, duration: 400.ms, delay: 200.ms).fadeIn(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigate(context, UserRole.emisor),
                    icon: const Icon(Icons.person, size: 18),
                    label: const Text('MODO DJ', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ).animate().slideY(begin: 1, duration: 400.ms, delay: 400.ms).fadeIn(),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, UserRole role) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => WaveHomeScreen(initialRole: role)),
    );
  }
}

enum UserRole { emisor, oyente }
