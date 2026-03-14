import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/wavy_theme.dart';
import 'features/wave/providers/wave_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/track/providers/track_provider.dart';
import 'features/voice/providers/voice_provider.dart';
import 'features/quality/providers/quality_provider.dart';
import 'features/auth/screens/role_selection_screen.dart';

void main() {
  runApp(const WavyApp());
}

class WavyApp extends StatelessWidget {
  const WavyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WaveProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => TrackProvider()),
        ChangeNotifierProvider(create: (_) => VoiceProvider()),
        ChangeNotifierProvider(create: (_) => QualityProvider()),
      ],
      builder: (context, child) {
        return Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return FutureBuilder(
              future: authProvider.initialize(),
              builder: (context, snapshot) {
                return MaterialApp(
                  title: 'WAVY',
                  theme: WavyTheme.darkTheme,
                  home: const RoleSelectionScreen(),
                  debugShowCheckedModeBanner: false,
                );
              },
            );
          },
        );
      },
    );
  }
}
