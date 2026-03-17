import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/wavy_theme.dart';
import '../../../core/services/music_service.dart';
import '../../../core/models/track.dart';
import '../../../core/services/hybrid_audio_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/playback_sync_service.dart';
import '../providers/wave_provider.dart';
import '../widgets/wave_list.dart';
import '../widgets/wave_info_card.dart';
import '../widgets/audio_stream_widget.dart';
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
  bool _transmittingMic = false;
  bool _useCloudStorage = true;
  Duration _position = Duration.zero;
  // Chat notification (like AudiShare messageNotify)
  String? _chatNotifyText;
  Timer? _chatNotifyTimer;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;
  HybridAudioService? _hybrid;
  late AnimationController _rippleController;
  bool _chatNotifyListening = false;
  bool _reconnectListening = false;
  bool _appInForeground = true;

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
    _posSub = MusicService.audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durSub = MusicService.audioPlayer.durationStream.listen((_) {});
    _stateSub = MusicService.audioPlayer.playerStateStream.listen((s) {
      if (mounted) setState(() => _isPlaying = s.playing);
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
    _durSub?.cancel();
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
    debugPrint('🚀 _startTransmitting called, socket connected: ${wp.toString()}');
    // Register listener BEFORE creating wave to avoid race condition
    wp.addListener(_onWaveCreated);
    wp.createWave('Mi Wave', 'DJ ${auth.displayName ?? 'Anon'}');
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
      context.read<TrackProvider>().initialize(waveId);
      context.read<VoiceProvider>().initialize(waveId, userId, isOwner: true);
      PlaybackSyncService.startAsDJ(waveId);
      _listenChatNotifications();
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
      setState(() => _chatNotifyText = last.message);
      _chatNotifyTimer?.cancel();
      _chatNotifyTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _chatNotifyText = null);
      });
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
      body: Consumer<WaveProvider>(
        builder: (context, wp, _) {
          return Stack(
            children: [
              // Background
              Container(color: WavyTheme.darkBackground),
              const ParticleBackground(),
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
              // Mic FAB + ripple (emisor only, like AudiShare)
              if (_currentRole == UserRole.emisor && wp.currentWave != null)
                _buildMicFab(),
              // Sidebar overlay (waves for oyente, playlist for emisor)
              if (_sidebarVisible) _buildSidebar(wp),
              // Chat overlay
              if (_chatVisible && wp.currentWave != null) _buildChat(wp),
            ],
          );
        },
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
    if (_currentRole == UserRole.emisor) return _buildEmisorGreet(wp);
    return _buildOyenteGreet(wp);
  }

  Widget _buildOyenteGreet(WaveProvider wp) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Escucha las canciones de otros',
              style: TextStyle(color: WavyTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text(
            'Este es un streaming en vivo, aquí puedes escuchar las canciones de otras personas en tiempo real.',
            style: TextStyle(color: WavyTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => setState(() => _sidebarVisible = true),
            icon: const Icon(Icons.headphones, size: 16),
            label: const Text('Ver waves'),
          ),
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
              style: TextStyle(color: WavyTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text(
            'Este es un streaming en vivo, aquí puedes sonar tus canciones para que otras personas las escuchen en tiempo real.',
            style: TextStyle(color: WavyTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => setState(() => _sidebarVisible = true),
                icon: const Icon(Icons.headphones, size: 16),
                label: const Text('Abrir lista de canciones'),
              ),
              ElevatedButton.icon(
                onPressed: () => _startTransmitting(),
                icon: const Icon(Icons.public, size: 16),
                label: const Text('Transmitir'),
              ),
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
            const AudioStreamWidget(),
            const SizedBox(height: 16),
            // Recent tracks
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
              ...tp.playedTracks.take(10).map((t) => Container(
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
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatPreview() {
    return GestureDetector(
      onTap: () => setState(() => _chatVisible = true),
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Chat icon + badge
            Stack(
              children: [
                const Icon(Icons.send, color: WavyTheme.textPrimary, size: 22),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Consumer<ChatProvider>(
                    builder: (_, chat, __) => Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: WavyTheme.accentRed, shape: BoxShape.circle),
                      child: Text('${chat.publicMessages.length}', style: const TextStyle(color: Colors.white, fontSize: 9)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Floating message notification (like AudiShare messageNotify)
            if (_chatNotifyText != null)
              Expanded(
                child: AnimatedOpacity(
                  opacity: _chatNotifyText != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: GestureDetector(
                    onTap: () => setState(() => _chatVisible = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(2),
                          topRight: Radius.circular(22),
                          bottomLeft: Radius.circular(2),
                          bottomRight: Radius.circular(22),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xE6FFFFFF)),
                            child: const ClipOval(child: Icon(Icons.person, size: 16, color: WavyTheme.textSecondary)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _chatNotifyText!,
                              style: const TextStyle(color: Color(0xFF777777), fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              const Text('Chat', style: TextStyle(color: WavyTheme.textSecondary, fontSize: 13)),
          ],
        ),
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
            onTap: () {
              setState(() => _transmittingMic = !_transmittingMic);
              context.read<VoiceProvider>().toggleLocutor();
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
        // Progress bar (like AudiShare #progressbar)
        GestureDetector(
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
            height: 3,
            width: double.infinity,
            color: const Color(0xFF757575),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: Container(height: 3, color: WavyTheme.primaryRed),
            ),
          ),
        ),
        // Controls
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: WavyTheme.headerBg,
          child: Row(
            children: [
              IconButton(
                onPressed: () => _skipTrack(-1),
                icon: const Icon(Icons.skip_previous, color: WavyTheme.textPrimary, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: IconButton(
                  onPressed: () async {
                    if (_isPlaying) {
                      await MusicService.pauseMusic();
                    } else {
                      await MusicService.resumeMusic();
                    }
                  },
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: WavyTheme.textPrimary, size: 28),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              IconButton(
                onPressed: () => _skipTrack(1),
                icon: const Icon(Icons.skip_next, color: WavyTheme.textPrimary, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.volume_down, color: WavyTheme.textSecondary, size: 16),
              SizedBox(
                width: 80,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: WavyTheme.textPrimary,
                    inactiveTrackColor: const Color(0xFF32334F),
                    thumbColor: WavyTheme.textPrimary,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: MusicService.audioPlayer.volume,
                    onChanged: (v) => MusicService.audioPlayer.setVolume(v),
                  ),
                ),
              ),
              const Icon(Icons.volume_up, color: WavyTheme.textSecondary, size: 16),
              const SizedBox(width: 8),
              Text(_fmt(_position), style: const TextStyle(color: WavyTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOyenteFooter(WaveProvider wp) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: WavyTheme.headerBg,
      child: Row(
        children: [
          IconButton(
            onPressed: () {},
            icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow, color: WavyTheme.textPrimary, size: 24),
          ),
          const Icon(Icons.volume_down, color: WavyTheme.textSecondary, size: 16),
          SizedBox(
            width: 80,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: WavyTheme.textPrimary,
                inactiveTrackColor: const Color(0xFF32334F),
                thumbColor: WavyTheme.textPrimary,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 3,
              ),
              child: Slider(value: 0.5, onChanged: (v) {}),
            ),
          ),
          const Icon(Icons.volume_up, color: WavyTheme.textSecondary, size: 16),
          const SizedBox(width: 8),
          Text(_fmt(_position), style: const TextStyle(color: WavyTheme.textSecondary, fontSize: 12)),
          if (wp.currentWave != null) ...[
            const Text(' | ', style: TextStyle(color: WavyTheme.textSecondary, fontSize: 12)),
            Expanded(
              child: Text(
                wp.currentWave!.name,
                style: const TextStyle(color: WavyTheme.textSecondary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          // Bitrate monitor
          Consumer<QualityProvider>(
            builder: (_, qp, __) {
              final label = qp.localBitrate > 0
                  ? '${qp.localBitrate} kbits/s'
                  : 'Conectando';
              return Text(
                label,
                style: TextStyle(
                  color: qp.localBufferHealth == 'poor'
                      ? Colors.red
                      : qp.localBufferHealth == 'fair'
                          ? Colors.orange
                          : WavyTheme.textSecondary,
                  fontSize: 10,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () {
              wp.leaveWave();
              context.read<TrackProvider>().clearTracks();
              context.read<QualityProvider>().clear();
              PlaybackSyncService.stop();
              MusicService.stopMusic();
            },
            child: const Text('Salir', style: TextStyle(color: WavyTheme.primaryRed, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ─── SIDEBAR ───
  Widget _buildSidebar(WaveProvider wp) {
    return Stack(
      children: [
        // Backdrop
        GestureDetector(
          onTap: () => setState(() => _sidebarVisible = false),
          child: Container(color: Colors.black.withValues(alpha: 0.4)),
        ),
        // Panel from right
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: _currentRole == UserRole.emisor
                ? _buildPlaylistSidebar(wp)
                : WaveList(
                    waves: wp.onlineWaves,
                    activeWaveId: wp.currentWave?.id,
                    onClose: () => setState(() => _sidebarVisible = false),
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
                const Expanded(
                  child: TextField(
                    style: TextStyle(color: WavyTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Buscar canción...',
                      hintStyle: TextStyle(color: WavyTheme.textSecondary),
                      border: InputBorder.none,
                      isDense: true,
                    ),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open, size: 60, color: WavyTheme.textSecondary),
          const SizedBox(height: 8),
          const Text('Selecciona archivos locales', style: TextStyle(color: WavyTheme.textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              final tp = context.read<TrackProvider>();
              final result = await FilePicker.platform.pickFiles(
                type: FileType.audio,
                allowMultiple: false,
              );
              if (result != null && result.files.isNotEmpty) {
                final file = result.files.first;
                final track = Track(
                  title: file.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
                  artist: 'Local',
                  url: file.path,
                  isCurrent: false,
                  playedAt: DateTime.now(),
                );
                tp.updateCurrentTrack(track.title, track.artist, url: track.url);
                await MusicService.playTrack(track);
              }
            },
            icon: const Icon(Icons.audio_file, size: 16),
            label: const Text('Elegir archivo'),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackListView(List<Track> tracks) {
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
                    border: Border.all(color: WavyTheme.textPrimary),
                  ),
                  child: Icon(
                    playing ? Icons.stop : Icons.play_arrow,
                    size: 16,
                    color: WavyTheme.cornflowerBlue,
                  ),
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
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => _chatVisible = false),
          child: Container(color: Colors.black.withValues(alpha: 0.4)),
        ),
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: ChatPanel(
              waveId: wp.currentWave!.id,
              onClose: () => setState(() => _chatVisible = false),
            ),
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
      _listenChatNotifications();
      _listenEmisorReconnect();
    });
  }

  void _listenEmisorReconnect() {
    if (_reconnectListening) return;
    _reconnectListening = true;
    final wp = context.read<WaveProvider>();
    EmisorState? prevState;
    wp.addListener(() {
      if (!mounted || _currentRole != UserRole.oyente) return;
      final state = wp.emisorState;
      if (prevState == EmisorState.reconnecting && state == EmisorState.connected && wp.currentWave != null) {
        debugPrint('🔄 Emisor reconnected, restarting HLS for oyente');
        _startHls(wp.currentWave!.id);
      }
      prevState = state;
    });
  }
}
