import 'package:flutter/material.dart';
import '../../../core/theme/wavy_theme.dart';
import '../../wave/screens/wave_home_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              WavyTheme.darkBackground,
              Color(0xFF1A0A0A),
              WavyTheme.darkBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Text(
                  'WAVY',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: WavyTheme.primaryRed,
                    fontSize: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Live Audio Social Platform',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: WavyTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 60),
                
                // Role selection
                Text(
                  '¿Cómo quieres entrar?',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                
                // EMISOR button
                SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WaveHomeScreen(initialRole: UserRole.emisor),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WavyTheme.primaryRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.radio, size: 32, color: Colors.white),
                        const SizedBox(height: 8),
                        Text(
                          'EMISOR',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Transmitir música',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // OYENTE button
                SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WaveHomeScreen(initialRole: UserRole.oyente),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WavyTheme.cardBackground,
                      side: BorderSide(color: WavyTheme.primaryRed.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.headphones, size: 32, color: WavyTheme.primaryRed),
                        const SizedBox(height: 8),
                        Text(
                          'OYENTE',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: WavyTheme.primaryRed,
                          ),
                        ),
                        Text(
                          'Escuchar música',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: WavyTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum UserRole { emisor, oyente }