import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/wavy_theme.dart';
import '../../../core/services/music_service.dart';
import '../../../core/models/track.dart';
import '../../../core/services/hybrid_audio_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/services/mic_stream_service.dart';
import '../../../core/services/playback_sync_service.dart';
import '../providers/wave_provider.dart';
import '../widgets/wave_list.dart';
import '../widgets/wave_info_card.dart';
import '../widgets/particle_background.dart';
import '../../auth/screens/role_selection_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../track/providers/track_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/widgets/chat_panel.dart';
import '../../voice/providers/voice_provider.dart';
import '../../quality/providers/quality_provider.dart';

class WaveHomeScreen extends StatefulWidget {
  final UserRole? initialRole;
  const WaveHomeScreen({super.key, this.initialRole});

  @override
  State<WaveHomeScreen> createState() => _WaveHomeScreenState();
}

class _WaveHomeScreenState extends State<WaveHomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  UserRole? _currentRole;
  bool _sidebarVisible = false;
  bool _chatVisible = false;
  String? _selectedSong;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _transmittingMic = false;
  bool _useCloudStorage = true;
  List<Track> _localTracks = []; // ignore: prefer_final_fields
  String _searchText = '';
  Duration _position = Duration.zero;
  // Chat notification (like AudiShare messageNotify)
  Timer? _chatNotifyTimer;
  List<String> _floatingReactions = []; // ignore: prefer_final_fields
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;
  HybridAudioService? _hybrid;
  late AnimationController _rippleController;
  bool _chatNotifyListening = false;
  bool _reconnectListening = false;
  bool _appInForeground = true;
  bool _reactionListening = false;
  bool _locutorListening = false;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.initialRole;
    _rippleController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _setupAudio();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<WaveProvider>().initialize(auth.userId!);
    });
  }

  void _setupAudio() {
    // Position updates: throttle to 1/second for UI (progress bar only needs ~1fps)
    _posSub = MusicService.audioPlayer.positionStream
        .where((_) => mounted)
        .listen((p) {
      // Only rebuild if second changed (avoid 4x/sec rebuilds)
      if (p.inSeconds != _position.inSeconds) {
        setState(() => _position = p);
      }
    });
    _stateSub = MusicService.audioPlayer.playerStateStream.listen((s) {
      if (!mounted) return;
      final playing = s.playing;
      final loading = s.processingState == ProcessingState.loading ||
                      s.processingState == ProcessingState.buffering;
      if (playing != _isPlaying || loading != _isLoading) {
        setState(() {
          _isPlaying = playing;
          _isLoading = loading;
        });
      }
      // Auto-next: when track completes, play next (DJ only)
      if (s.processingState == ProcessingState.completed &&
          _currentRole == UserRole.emisor) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _skipTrack(1);
        });
      }
    });

    // Wire notification skip buttons
    final handler = MusicService.handler;
    if (handler != null) {
      handler.onSkipNext = () => _skipTrack(1);
      handler.onSkipPrevious = () => _skipTrack(-1);
    }
  }

  void _skipTrack(int direction) {
    final tracks = MusicService.s3Tracks;
    if (tracks.isEmpty) return;
    final currentIdx = tracks.indexWhere((t) => t.url == _selectedSong);
    final nextIdx = (currentIdx + direction).clamp(0, tracks.length - 1);
    final track = tracks[nextIdx];
    setState(() => _selectedSong = track.url);
    context.read<TrackProvider>().updateCurrentTrack(track.title, track.artist, url: track.url);
    MusicService.playTrack(track);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rippleController.dispose();
    _chatNotifyTimer?.cancel();
    _posSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appInForeground = true;
      final auth = context.read<AuthProvider>();
      if (auth.userId != null) {
        context.read<WaveProvider>().initialize(auth.userId!);
      }
    } else if (state == AppLifecycleState.paused) {
      _appInForeground = false;
    }
  }

  void _startTransmitting() async {
    final wp = context.read<WaveProvider>();
    final auth = context.read<AuthProvider>();
    final prefs = await SharedPreferences.getInstance();
    final waveName = prefs.getString('wavy_wave_name') ?? 'Mi Wave';
    final djName = prefs.getString('wavy_dj_name') ?? 'DJ ${auth.displayName ?? 'Anon'}';
    debugPrint('🚀 _startTransmitting called, socket connected: ${wp.toString()}');
    wp.addListener(_onWaveCreated);
    wp.createWave(waveName, djName);
    _hybrid = HybridAudioService();
    try {
      await _hybrid!.joinRoom('test-wave', 'emisor-${DateTime.now().millisecondsSinceEpoch}', isHost: true);
    } catch (_) {}
  }

  void _onWaveCreated() {
    final wp = context.read<WaveProvider>();
    if (wp.currentWave != null && wp.isOwner) {
      wp.removeListener(_onWaveCreated);
      final waveId = wp.currentWave!.id;
      final userId = context.read<AuthProvider>().userId!;
      debugPrint('✅ Wave created: $waveId, initializing chat/track/voice');
      context.read<ChatProvider>().initialize(waveId, userId);
      context.read<TrackProvider>().initialize(waveId, isOwner: true);
      context.read<VoiceProvider>().initialize(waveId, userId, isOwner: true);
      PlaybackSyncService.startAsDJ(waveId);
      _listenChatNotifications();
      _listenReactions();
      _listenLocutorVolume();
    }
  }

  void _listenChatNotifications() {
    if (_chatNotifyListening) return;
    _chatNotifyListening = true;
    final chat = context.read<ChatProvider>();
    chat.addListener(() {
      if (!mounted) return;
      final msgs = chat.publicMessages;
      if (msgs.isEmpty) return;
      final last = msgs.last;
      final userId = context.read<AuthProvider>().userId;
      if (last.userId == userId) return; // Don't notify own messages
      if (!_appInForeground) {
        NotificationService.showChatNotification(last.message);
      }
    });
  }

  Future<void> _exit(WaveProvider wp) async {
    if (_currentRole == UserRole.emisor && wp.currentWave != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: WavyTheme.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: WavyTheme.borderColor)),
                ),
                child: const Text(
                  'Saliendo del modo DJ...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: WavyTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                color: WavyTheme.darkBackground,
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 58, color: WavyTheme.textSecondary),
                    const SizedBox(height: 12),
                    const Text(
                      '¡Si sales puedes perder a todos los oyentes!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: WavyTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '¿Estás seguro que deseas salir?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: WavyTheme.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4B4D67)),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cancel, size: 16),
                            SizedBox(width: 4),
                            Text('NO'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 16),
                            SizedBox(width: 4),
                            Text('SI, Salir'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
    }
    await MusicService.stopMusic();
    PlaybackSyncService.stop();
    MicStreamService.stopBroadcasting();
    MicStreamService.stopListening();
    if (_currentRole == UserRole.emisor && wp.currentWave != null) {
      if (wp.isStreaming) await wp.stopStreaming();
      await wp.stopWave();
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen()));
  }

  String _fmt(Duration d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.inHours)}:${p(d.inMinutes.remainder(60))}:${p(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: WavyTheme.darkBackground),
          const RepaintBoundary(child: ParticleBackground()),
          Consumer<WaveProvider>(
            builder: (context, wp, _) {
              return Stack(
                children: [
              // Main layout (header + content + footer)
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(wp),
                    Expanded(child: _buildContent(wp)),
                    _buildFooter(wp),
                  ],
                ),
              ),
              // Floating reactions overlay
              if (_floatingReactions.isNotEmpty)
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _floatingReactions.map((e) => TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      builder: (_, v, child) => Opacity(
                        opacity: 1.0 - v * 0.5,
                        child: Transform.translate(
                          offset: Offset(0, -v * 60),
                          child: child,
                        ),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 32)),
                    )).toList(),
                  ),
                ),
              // Mic FAB + ripple (emisor only, like AudiShare)
              if (_currentRole == UserRole.emisor && wp.currentWave != null)
                _buildMicFab(),
              // Sidebar overlay (waves for oyente, playlist for emisor)
              _buildSidebar(wp),
              // Chat overlay
              if (wp.currentWave != null) _buildChat(wp),
            ],
          );
            },
          ),
        ],
      ),
    );
  }

  // ─── HEADER ───
  Widget _buildHeader(WaveProvider wp) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: WavyTheme.headerBg,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _exit(wp),
            child: Row(
              children: [
                const Icon(Icons.headphones, color: WavyTheme.primaryRed, size: 22),
                const SizedBox(width: 6),
                const Text('WAVY', style: TextStyle(color: WavyTheme.primaryRed, fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Spacer(),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _currentRole == UserRole.emisor ? WavyTheme.primaryRed : WavyTheme.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: WavyTheme.primaryRed.withValues(alpha: 0.5)),
            ),
            child: Text(
              _currentRole == UserRole.emisor ? 'DJ' : 'OYENTE',
              style: TextStyle(
                color: _currentRole == UserRole.emisor ? Colors.white : WavyTheme.primaryRed,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Sidebar toggle (hamburger)
          IconButton(
            onPressed: () => setState(() => _sidebarVisible = !_sidebarVisible),
            icon: const Icon(Icons.menu, color: WavyTheme.textPrimary, size: 24),
          ),
        ],
      ),
    );
  }

  // ─── CONTENT ───
  Widget _buildContent(WaveProvider wp) {
    if (wp.currentWave != null) return _buildInWave(wp);
    if (!SocketService().isConnected) return _buildErrorScreen();
    if (_currentRole == UserRole.emisor) return _buildEmisorGreet(wp);
    return _buildOyenteGreet(wp);
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.power_off, size: 80, color: WavyTheme.textSecondary)
                .animate().fadeIn(duration: 400.ms).scale(begin: const Offset(1.4, 1.4)),
            const SizedBox(height: 16),
            const Text('Oops, hubo un problema!',
                    style: TextStyle(color: WavyTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700))
                .animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 12),
            const Text('No se pudo conectar al servidor. Verifica tu conexión a internet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: WavyTheme.textSecondary, fontSize: 14))
                .animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                final auth = context.read<AuthProvider>();
                SocketService().connect(auth.userId!);
                context.read<WaveProvider>().initialize(auth.userId!);
                setState(() {});
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
            ).animate().slideY(begin: 1, delay: 600.ms).fadeIn(),
          ],
        ),
      ),
    );
  }

  Widget _buildOyenteGreet(WaveProvider wp) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Escucha las canciones de otros',
                  style: TextStyle(color: WavyTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.w700))
              .animate().slideX(begin: 1, duration: 400.ms).fadeIn(),
          const SizedBox(height: 12),
          const Text(
            'Este es un streaming en vivo, aquí puedes escuchar las canciones de otras personas en tiempo real.',
            style: TextStyle(color: WavyTheme.textSecondary, fontSize: 14),
          ).animate().slideX(begin: 1, delay: 150.ms, duration: 400.ms).fadeIn(),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => setState(() => _sidebarVisible = true),
            icon: const Icon(Icons.headphones, size: 16),
            label: const Text('Ver waves'),
          ).animate().slideY(begin: 1, delay: 300.ms, duration: 400.ms).fadeIn(),
        ],
      ),
    );
  }

  Widget _buildEmisorGreet(WaveProvider wp) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Haz que tus canciones las escuchen otros',
                  style: TextStyle(color: WavyTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.w700))
              .animate().slideX(begin: 1, duration: 400.ms).fadeIn(),
          const SizedBox(height: 12),
          const Text(
            'Este es un streaming en vivo, aquí puedes sonar tus canciones para que otras personas las escuchen en tiempo real.',
            style: TextStyle(color: WavyTheme.textSecondary, fontSize: 14),
          ).animate().slideX(begin: 1, delay: 150.ms, duration: 400.ms).fadeIn(),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => setState(() => _sidebarVisible = true),
                icon: const Icon(Icons.headphones, size: 16),
                label: const Text('Abrir lista de canciones'),
              ).animate().slideY(begin: 1, delay: 300.ms, duration: 400.ms).fadeIn(),
              ElevatedButton.icon(
                onPressed: () => _startTransmitting(),
                icon: const Icon(Icons.public, size: 16),
                label: const Text('Transmitir'),
              ).animate().slideY(begin: 1, delay: 450.ms, duration: 400.ms).fadeIn(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInWave(WaveProvider wp) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          WaveInfoCard(wave: wp.currentWave!),
          const SizedBox(height: 16),
          if (_currentRole == UserRole.oyente) ...[
            const SizedBox(height: 16),
            _buildRecentTracks(),
          ],
          if (_currentRole == UserRole.emisor) ...[
            // Streaming status
            _buildStreamingStatus(wp),
            const SizedBox(height: 16),
            _buildRecentTracks(),
          ],
          // Chat preview bar
          if (wp.currentWave != null) _buildChatPreview(),
          if (wp.currentWave != null && _currentRole == UserRole.oyente) _buildReactionBar(wp),
        ],
      ),
    );
  }

  Widget _buildStreamingStatus(WaveProvider wp) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: wp.isStreaming ? WavyTheme.primaryRed.withValues(alpha: 0.1) : WavyTheme.cardBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            wp.isStreaming ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: wp.isStreaming ? WavyTheme.primaryRed : WavyTheme.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            wp.isStreaming ? 'TRANSMITIENDO EN VIVO' : 'INICIANDO...',
            style: TextStyle(
              color: wp.isStreaming ? WavyTheme.primaryRed : WavyTheme.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTracks() {
    return Consumer<TrackProvider>(
      builder: (context, tp, _) {
        if (tp.playedTracks.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: WavyTheme.itemBgEven, borderRadius: BorderRadius.circular(6)),
            child: const Text('Estas son las canciones reproducidas', style: TextStyle(color: WavyTheme.textSecondary, fontSize: 13)),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Canciones recientes', style: TextStyle(color: WavyTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...tp.playedTracks.take(10).map((t) => GestureDetector(
                    onTap: () {
                      if (_currentRole == UserRole.emisor && t.url != null) {
                        context.read<TrackProvider>().updateCurrentTrack(t.title, t.artist, url: t.url);
                        MusicService.playTrack(t);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: WavyTheme.itemBgEven, borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        children: [
                          Icon(t.isCurrent ? Icons.stop : Icons.play_arrow, color: WavyTheme.cornflowerBlue, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(t.title, style: const TextStyle(color: WavyTheme.cornflowerBlue, fontSize: 13), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatPreview() {
    return Consumer<ChatProvider>(
      builder: (_, chat, __) {
        final messages = chat.publicMessages;
        final lastMessages = messages.length > 3
            ? messages.sublist(messages.length - 3)
            : messages;

        return GestureDetector(
          onTap: () => setState(() => _chatVisible = true),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: WavyTheme.cardBackground.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Messages with fade overlay
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.white, Colors.white],
                      stops: [0.0, 0.4, 1.0],
                    ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
                      child: lastMessages.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('No hay mensajes aún',
                                    style: TextStyle(color: WavyTheme.textSecondary, fontSize: 12)),
                              ),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: lastMessages.map((msg) {
                                final isSelf = msg.userId == context.read<AuthProvider>().userId;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelf ? WavyTheme.accentRed : const Color(0xE6FFFFFF),
                                        ),
                                        child: Icon(Icons.person, size: 14,
                                            color: isSelf ? Colors.white : WavyTheme.textSecondary),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          msg.message,
                                          style: TextStyle(
                                            color: isSelf ? WavyTheme.textPrimary : WavyTheme.textSecondary,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                ),
                // "Ir al chat" button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: WavyTheme.borderColor)),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 14, color: WavyTheme.cornflowerBlue),
                      const SizedBox(width: 6),
                      Text(
                        'Ir al chat · ${messages.length}',
                        style: const TextStyle(color: WavyTheme.cornflowerBlue, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── REACTIONS ───
  Widget _buildReactionBar(WaveProvider wp) {
    const reactions = ['⭐', '❤️', '🔥', '👏', '😂'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: reactions.map((emoji) {
          return GestureDetector(
            onTap: () {
              final auth = context.read<AuthProvider>();
              SocketService().emit('send-reaction', {
                'waveId': wp.currentWave!.id,
                'userId': auth.userId,
                'reaction': emoji,
              });
              setState(() => _floatingReactions = [..._floatingReactions, emoji]);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() {
                    _floatingReactions = _floatingReactions.length > 1
                        ? _floatingReactions.sublist(1)
                        : [];
                  });
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── MIC FAB (like AudiShare's float + float-ripple) ───
  Widget _buildMicFab() {
    return Positioned(
      bottom: 80,
      right: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_transmittingMic)
            AnimatedBuilder(
              animation: _rippleController,
              builder: (context, _) {
                return SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _rippleCircle(_rippleController.value),
                      _rippleCircle((_rippleController.value + 0.5) % 1.0),
                    ],
                  ),
                );
              },
            ),
          GestureDetector(
            onTap: () async {
              final wp = context.read<WaveProvider>();
              setState(() => _transmittingMic = !_transmittingMic);
              context.read<VoiceProvider>().toggleLocutor();
              if (_transmittingMic && wp.currentWave != null) {
                await MicStreamService.startBroadcasting(wp.currentWave!.id);
              } else {
                await MicStreamService.stopBroadcasting();
              }
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _transmittingMic ? WavyTheme.primaryRed : const Color(0xFF00CC99),
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3, offset: Offset(2, 2))],
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rippleCircle(double v) {
    return Container(
      width: 120 * v,
      height: 120 * v,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 1.0 - v), width: 4),
      ),
    );
  }

  // ─── FOOTER ───
  Widget _buildFooter(WaveProvider wp) {
    if (_currentRole == UserRole.emisor && wp.currentWave != null) return _buildEmisorFooter();
    if (_currentRole == UserRole.oyente && wp.currentWave != null) return _buildOyenteFooter(wp);
    return const SizedBox.shrink();
  }

  Widget _buildEmisorFooter() {
    final duration = MusicService.audioPlayer.duration ?? Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? (_position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Time labels + progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(_fmt(_position), style: const TextStyle(color: WavyTheme.textSecondary, fontSize: 10)),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTapDown: (details) {
                    if (duration.inMilliseconds > 0) {
                      final box = context.findRenderObject() as RenderBox;
                      final ratio = details.localPosition.dx / box.size.width;
                      final seekTo = Duration(milliseconds: (duration.inMilliseconds * ratio).toInt());
                      MusicService.audioPlayer.seek(seekTo);
                      PlaybackSyncService.emitSeek();
                    }
                  },
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF32334F),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: WavyTheme.primaryRed,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(_fmt(duration), style: const TextStyle(color: WavyTheme.textSecondary, fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Controls row
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: WavyTheme.headerBg,
          child: Row(
            children: [
              // Transport controls
              IconButton(
                onPressed: () => _skipTrack(-1),
                icon: const Icon(Icons.skip_previous_rounded, color: WavyTheme.textPrimary, size: 28),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              _isLoading
                  ? const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, color: WavyTheme.primaryRed))
                  : IconButton(
                      onPressed: () async {
                        if (_isPlaying) {
                          await MusicService.pauseMusic();
                        } else {
                          await MusicService.resumeMusic();
                        }
                        PlaybackSyncService.emitPlayPause();
                      },
                      icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: WavyTheme.textPrimary, size: 36),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () => _skipTrack(1),
                icon: const Icon(Icons.skip_next_rounded, color: WavyTheme.textPrimary, size: 28),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Spacer(),
              // Volume
              const Icon(Icons.volume_down_rounded, color: WavyTheme.textSecondary, size: 18),
              SizedBox(
                width: 90,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: WavyTheme.textPrimary,
                    inactiveTrackColor: const Color(0xFF32334F),
                    thumbColor: WavyTheme.textPrimary,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: MusicService.audioPlayer.volume,
                    onChanged: (v) => MusicService.audioPlayer.setVolume(v),
                  ),
                ),
              ),
              const Icon(Icons.volume_up_rounded, color: WavyTheme.textSecondary, size: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOyenteFooter(WaveProvider wp) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: WavyTheme.headerBg,
      child: Row(
        children: [
          // Play/stop
          _isLoading
              ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, color: WavyTheme.primaryRed))
              : IconButton(
                  onPressed: () {},
                  icon: Icon(_isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_filled,
                      color: WavyTheme.textPrimary, size: 32),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
          const SizedBox(width: 12),
          // Volume
          const Icon(Icons.volume_down_rounded, color: WavyTheme.textSecondary, size: 18),
          SizedBox(
            width: 80,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: WavyTheme.textPrimary,
                inactiveTrackColor: const Color(0xFF32334F),
                thumbColor: WavyTheme.textPrimary,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 3,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: MusicService.audioPlayer.volume,
                onChanged: (v) => MusicService.audioPlayer.setVolume(v),
              ),
            ),
          ),
          const Icon(Icons.volume_up_rounded, color: WavyTheme.textSecondary, size: 18),
          const Spacer(),
          // Live time (time since DJ started)
          const Icon(Icons.circle, color: WavyTheme.primaryRed, size: 8),
          const SizedBox(width: 6),
          Text(
            _fmt(wp.currentWave != null
                ? DateTime.now().difference(wp.currentWave!.createdAt)
                : Duration.zero),
            style: const TextStyle(color: WavyTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─── SIDEBAR ───
  Widget _buildSidebar(WaveProvider wp) {
    final width = MediaQuery.of(context).size.width * 0.85;
    return Stack(
      children: [
        // Backdrop
        if (_sidebarVisible)
          GestureDetector(
            onTap: () => setState(() => _sidebarVisible = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: _sidebarVisible ? Colors.black.withValues(alpha: 0.4) : Colors.transparent,
            ),
          ),
        // Panel slides from right
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          right: _sidebarVisible ? 0 : -width,
          width: width,
          child: Material(
            elevation: _sidebarVisible ? 20 : 0,
            shadowColor: Colors.black,
            color: Colors.transparent,
            child: _currentRole == UserRole.emisor
                ? _buildPlaylistSidebar(wp)
                : WaveList(
                    waves: wp.onlineWaves,
                    activeWaveId: wp.currentWave?.id,
                    onClose: () => setState(() => _sidebarVisible = false),
                    onRefresh: () => wp.refreshWaves(),
                    onWaveTap: (wave) {
                      wp.joinWave(wave.id);
                      _startHls(wave.id);
                      _initTrackProvider(wave.id);
                      setState(() => _sidebarVisible = false);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistSidebar(WaveProvider wp) {
    return Container(
      color: WavyTheme.cardBackground,
      child: Column(
        children: [
          // Header
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)]),
            child: Row(
              children: [
                const Icon(Icons.search, color: WavyTheme.textPrimary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: WavyTheme.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Buscar canción...',
                      hintStyle: TextStyle(color: WavyTheme.textSecondary),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchText = v),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _sidebarVisible = false),
                  icon: const Icon(Icons.cancel, color: WavyTheme.textPrimary, size: 22),
                ),
              ],
            ),
          ),
          // Song list
          Expanded(
            child: _useCloudStorage ? _buildCloudSongList() : _buildLocalSongList(),
          ),
          // Footer - toggle almacenamiento
          GestureDetector(
            onTap: () => setState(() {
              _useCloudStorage = !_useCloudStorage;
            }),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)]),
              child: Row(
                children: [
                  Icon(
                    _useCloudStorage ? Icons.cloud : Icons.archive,
                    color: WavyTheme.textPrimary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  const Text('Almacenamiento: ', style: TextStyle(color: WavyTheme.textFaded, fontSize: 13)),
                  Text(
                    _useCloudStorage ? 'NUBE (S3)' : 'LOCAL',
                    style: const TextStyle(color: WavyTheme.cornflowerBlue, fontSize: 13),
                  ),
                  const Spacer(),
                  const Icon(Icons.swap_horiz, color: WavyTheme.textSecondary, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SONG LISTS ───
  Widget _buildCloudSongList() {
    return FutureBuilder<List<Track>>(
      future: MusicService.fetchTracks(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: WavyTheme.primaryRed));
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 60, color: Colors.red),
                  const SizedBox(height: 8),
                  const Text('Error al cargar canciones de S3', style: TextStyle(color: Colors.red, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('${snap.error}', style: const TextStyle(color: WavyTheme.textSecondary, fontSize: 11), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: () => setState(() {}), child: const Text('Reintentar')),
                ],
              ),
            ),
          );
        }
        if (!snap.hasData || snap.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_queue, size: 60, color: WavyTheme.textSecondary),
                SizedBox(height: 8),
                Text('No hay canciones en S3', style: TextStyle(color: WavyTheme.textSecondary)),
              ],
            ),
          );
        }
        return _buildTrackListView(snap.data!);
      },
    );
  }

  Widget _buildLocalSongList() {
    if (_localTracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open, size: 60, color: WavyTheme.textSecondary),
            const SizedBox(height: 8),
            const Text('Selecciona archivos de audio', style: TextStyle(color: WavyTheme.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _pickLocalFiles,
              icon: const Icon(Icons.audio_file, size: 16),
              label: const Text('Elegir archivos'),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(child: _buildTrackListView(_localTracks)),
        Padding(
          padding: const EdgeInsets.all(8),
          child: ElevatedButton.icon(
            onPressed: _pickLocalFiles,
            icon: const Icon(Icons.add, size: 16),
            label: Text('${_localTracks.length} archivos · Agregar más'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 36)),
          ),
        ),
      ],
    );
  }

  void _pickLocalFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final newTracks = result.files
          .where((f) => f.path != null)
          .map((f) => Track(
                title: f.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
                artist: 'Local',
                url: f.path,
                isCurrent: false,
                playedAt: DateTime.now(),
              ))
          .toList();
      setState(() {
        // Add without duplicates
        for (final t in newTracks) {
          if (!_localTracks.any((e) => e.url == t.url)) _localTracks.add(t);
        }
      });
    }
  }

  Widget _buildTrackListView(List<Track> allTracks) {
    final tracks = _searchText.isEmpty
        ? allTracks
        : allTracks.where((t) => t.title.toLowerCase().contains(_searchText.toLowerCase())).toList();
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        final track = tracks[i];
        final playing = _selectedSong == track.url;
        return GestureDetector(
          onTap: () async {
            setState(() => _selectedSong = track.url);
            context.read<TrackProvider>().updateCurrentTrack(track.title, track.artist, url: track.url);
            await MusicService.playTrack(track);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            color: i.isOdd ? WavyTheme.itemBgOdd : WavyTheme.itemBgEven,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: playing ? WavyTheme.primaryRed : WavyTheme.textPrimary),
                    gradient: const LinearGradient(colors: [Color(0xFF32334F), Color(0xFF4F527E)]),
                  ),
                  child: playing
                      ? const Icon(Icons.album, size: 20, color: WavyTheme.primaryRed)
                          .animate(onPlay: (c) => c.repeat())
                          .rotate(duration: 2000.ms)
                      : const Icon(Icons.play_arrow, size: 16, color: WavyTheme.cornflowerBlue),
                ),
                Expanded(
                  child: Text(
                    track.title,
                    style: TextStyle(
                      color: playing ? WavyTheme.primaryRed : WavyTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: playing ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── CHAT ───
  Widget _buildChat(WaveProvider wp) {
    final width = MediaQuery.of(context).size.width * 0.85;
    return Stack(
      children: [
        if (_chatVisible)
          GestureDetector(
            onTap: () => setState(() => _chatVisible = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: _chatVisible ? Colors.black.withValues(alpha: 0.4) : Colors.transparent,
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          right: _chatVisible ? 0 : -width,
          width: width,
          child: Material(
            elevation: _chatVisible ? 20 : 0,
            shadowColor: Colors.black,
            color: Colors.transparent,
            child: wp.currentWave != null
                ? ChatPanel(
                    waveId: wp.currentWave!.id,
                    djUserId: wp.currentWave!.ownerId,
                    onClose: () => setState(() => _chatVisible = false),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  // ─── HELPERS ───
  void _startHls(String waveId) async {
    _hybrid = HybridAudioService();
    try {
      await _hybrid!.joinRoom(waveId, 'oyente-${DateTime.now().millisecondsSinceEpoch}', isHost: false);
    } catch (_) {}
  }

  void _initTrackProvider(String waveId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().userId!;
      context.read<TrackProvider>().initialize(waveId);
      context.read<ChatProvider>().initialize(waveId, userId);
      context.read<VoiceProvider>().initialize(waveId, userId, isOwner: false);
      context.read<QualityProvider>().initialize(waveId, userId, isOwner: false);
      PlaybackSyncService.startAsListener(waveId);
      MicStreamService.startListening(waveId);
      _listenChatNotifications();
      _listenEmisorReconnect();
      _listenReactions();
      _listenLocutorVolume();
    });
  }

  void _listenLocutorVolume() {
    if (_locutorListening || _currentRole != UserRole.oyente) return;
    _locutorListening = true;
    final vp = context.read<VoiceProvider>();
    vp.addListener(() {
      if (!mounted) return;
      MusicService.audioPlayer.setVolume(vp.suggestedMusicVolume);
    });
  }

  void _listenReactions() {
    if (_reactionListening) return;
    _reactionListening = true;
    SocketService().on('reaction-received', (data) {
      if (!mounted) return;
      final emoji = data['reaction']?.toString() ?? '❤️';
      setState(() => _floatingReactions = [..._floatingReactions, emoji]);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _floatingReactions = _floatingReactions.length > 1
                ? _floatingReactions.sublist(1)
                : [];
          });
        }
      });
    });
  }

  void _listenEmisorReconnect() {
    if (_reconnectListening) return;
    _reconnectListening = true;
    final wp = context.read<WaveProvider>();
    EmisorState? prevState;
    bool hadWave = false;
    wp.addListener(() {
      if (!mounted || _currentRole != UserRole.oyente) return;
      final state = wp.emisorState;
      // DJ reconnected
      if (prevState == EmisorState.reconnecting && state == EmisorState.connected && wp.currentWave != null) {
        debugPrint('🔄 Emisor reconnected, restarting for oyente');
        _startHls(wp.currentWave!.id);
      }
      // DJ went offline (wave-offline)
      if (hadWave && wp.currentWave == null) {
        MusicService.stopMusic();
        PlaybackSyncService.stop();
        MicStreamService.stopListening();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El DJ ha terminado la transmisión'),
              backgroundColor: WavyTheme.primaryRed,
            ),
          );
        }
      }
      hadWave = wp.currentWave != null;
      prevState = state;
    });
  }
}
