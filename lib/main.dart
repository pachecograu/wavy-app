import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'core/theme/wavy_theme.dart';
import 'core/services/wavy_audio_handler.dart';
import 'core/services/music_service.dart';
import 'core/services/notification_service.dart';
import 'features/wave/providers/wave_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/track/providers/track_provider.dart';
import 'features/voice/providers/voice_provider.dart';
import 'features/quality/providers/quality_provider.dart';
import 'features/auth/screens/role_selection_screen.dart';

class WavyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

Future<void> main() async {
  HttpOverrides.global = WavyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  final handler = await AudioService.init(
    builder: () => WavyAudioHandler(MusicService.audioPlayer),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.wavy.audio',
      androidNotificationChannelName: 'WAVY Audio',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
    ),
  );
  MusicService.setHandler(handler);
  await NotificationService.init();

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
