import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/theme/wavy_theme.dart';
import '../../../core/services/music_service.dart';
import '../../../core/services/hybrid_audio_service.dart';
import '../providers/wave_provider.dart';
import '../widgets/wave_list.dart';
import '../widgets/wave_info_card.dart';
import '../widgets/audio_stream_widget.dart';
import '../../auth/screens/role_selection_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../track/providers/track_provider.dart';

class WaveHomeScreen extends StatefulWidget {
  final UserRole? initialRole;
  
  const WaveHomeScreen({super.key, this.initialRole});

  @override
  State<WaveHomeScreen> createState() => _WaveHomeScreenState();
}

class _WaveHomeScreenState extends State<WaveHomeScreen> with WidgetsBindingObserver {
  UserRole? _currentRole;
  bool _waveCreated = false;
  bool _showPlaylist = false;
  String? _selectedSong;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  
  // Store provider reference to avoid accessing it in dispose
  WaveProvider? _waveProvider;
  HybridAudioService? _hybridService;
  
  @override
  void initState() {
    super.initState();
    _currentRole = widget.initialRole;
    _setupAudioListeners();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      _waveProvider = context.read<WaveProvider>();
      _waveProvider!.initialize(authProvider.userId!);
      
      // Auto-create wave for emisor role
      if (_currentRole == UserRole.emisor && !_waveCreated) {
        _createAutoWave();
      }
    });
  }
  
  void _setupAudioListeners() {
    _positionSubscription = MusicService.audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });
    
    _durationSubscription = MusicService.audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });
    
    _playerStateSubscription = MusicService.audioPlayer.playerStateStream.listen((playerState) {
      if (mounted) {
        setState(() {
          _isPlaying = playerState.playing;
        });
      }
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setUserOfflineSync();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _hybridService?.leaveRoom();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _setUserOffline();
    }
  }
  
  void _setUserOfflineSync() {
    if (_waveProvider != null) {
      if (_currentRole == UserRole.emisor && _waveProvider!.currentWave != null) {
        // Stop streaming and wave synchronously
        MusicService.stopMusicAndStreaming();
      } else if (_currentRole == UserRole.oyente && _waveProvider!.currentWave != null) {
        _waveProvider!.leaveWave();
      }
    }
  }
  
  void _setUserOffline() async {
    if (_waveProvider != null) {
      if (_currentRole == UserRole.emisor && _waveProvider!.currentWave != null) {
        // Stop streaming first, then stop wave
        if (_waveProvider!.isStreaming) {
          await _waveProvider!.stopStreaming();
        }
        await _waveProvider!.stopWave();
      } else if (_currentRole == UserRole.oyente && _waveProvider!.currentWave != null) {
        await _waveProvider!.leaveWave();
      }
    }
  }
  
  void _autoJoinHybridRoom() async {
    // Wait a bit for socket connection to establish
    await Future.delayed(const Duration(milliseconds: 500));
    
    _hybridService = HybridAudioService();
    try {
      await _hybridService!.joinRoom('test-wave', 'oyente-${DateTime.now().millisecondsSinceEpoch}', isHost: false);
      print('🌊 Auto-joined HLS room as listener');
    } catch (e) {
      print('❌ Error auto-joining HLS: $e');
    }
  }
  
  void _createAutoWave() async {
    if (!_waveCreated && _waveProvider != null) {
      _waveCreated = true;
      
      // Wait a bit for socket connection to establish
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Create wave
      _waveProvider!.createWave('Mi Wave', 'DJ ${DateTime.now().millisecondsSinceEpoch}');
      
      // Auto-start HLS transmission for emisor
      _hybridService = HybridAudioService();
      try {
        await _hybridService!.joinRoom('test-wave', 'emisor-${DateTime.now().millisecondsSinceEpoch}', isHost: true);
        print('🌊 Auto-started HLS transmission');
      } catch (e) {
        print('❌ Error auto-starting HLS: $e');
      }
    }
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Particle background placeholder
          Container(
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
          ),
          
          // Main content
          SafeArea(
            child: Consumer<WaveProvider>(
              builder: (context, waveProvider, child) {
                return Stack(
                  children: [
                    Row(
                      children: [
                        // Main content area - now full width
                        Expanded(
                          child: Column(
                            children: [
                              // Header
                              Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'WAVY',
                                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                            color: WavyTheme.primaryRed,
                                          ),
                                        ),
                                        Consumer<AuthProvider>(
                                          builder: (context, authProvider, child) {
                                            return Text(
                                              authProvider.displayName ?? 'Usuario',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: WavyTheme.textSecondary,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        // Playlist button for emisor
                                        if (_currentRole == UserRole.emisor && waveProvider.currentWave != null)
                                          IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _showPlaylist = !_showPlaylist;
                                              });
                                            },
                                            icon: Icon(
                                              _showPlaylist ? Icons.close : Icons.queue_music,
                                              color: WavyTheme.primaryRed,
                                              size: 28,
                                            ),
                                          ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: _currentRole == UserRole.emisor 
                                                ? WavyTheme.primaryRed 
                                                : WavyTheme.cardBackground,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: WavyTheme.primaryRed.withValues(alpha: 0.5),
                                            ),
                                          ),
                                          child: Text(
                                            _currentRole == UserRole.emisor ? 'EMISOR' : 'OYENTE',
                                            style: TextStyle(
                                              color: _currentRole == UserRole.emisor 
                                                  ? Colors.white 
                                                  : WavyTheme.primaryRed,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () async {
                                            // Stop music and streaming before leaving
                                            await MusicService.stopMusicAndStreaming();
                                            
                                            // Stop streaming and wave before leaving
                                            if (_currentRole == UserRole.emisor && waveProvider.currentWave != null) {
                                              if (waveProvider.isStreaming) {
                                                await waveProvider.stopStreaming();
                                              }
                                              await waveProvider.stopWave();
                                            }
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const RoleSelectionScreen(),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.swap_horiz,
                                            color: WavyTheme.textSecondary,
                                            size: 28,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Content based on role and current wave
                              Expanded(
                                child: waveProvider.currentWave != null
                                    ? _buildInWaveView(context, waveProvider)
                                    : _currentRole == UserRole.emisor
                                        ? _buildEmisorView(context, waveProvider)
                                        : _buildOyenteView(context, waveProvider),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Floating playlist panel with backdrop
                    if (_showPlaylist && _currentRole == UserRole.emisor) ...[
                      // Backdrop to close panel when tapping outside
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showPlaylist = false;
                            });
                          },
                          child: Container(
                            color: Colors.transparent,
                          ),
                        ),
                      ),
                      // Actual playlist panel
                      Positioned(
                        top: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 300,
                          decoration: BoxDecoration(
                            color: WavyTheme.cardBackground,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(-2, 0),
                              ),
                            ],
                          ),
                          child: Consumer<TrackProvider>(
                            builder: (context, trackProvider, child) {
                              return Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: WavyTheme.primaryRed.withOpacity(0.1),
                                      border: Border(
                                        bottom: BorderSide(
                                          color: WavyTheme.primaryRed.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.queue_music,
                                              color: WavyTheme.primaryRed,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Playlist',
                                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _showPlaylist = false;
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.close,
                                            color: WavyTheme.primaryRed,
                                            size: 20,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        // Available songs section
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: WavyTheme.primaryRed.withOpacity(0.1),
                                            border: Border(
                                              bottom: BorderSide(
                                                color: WavyTheme.primaryRed.withOpacity(0.3),
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.library_music,
                                                color: WavyTheme.primaryRed,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Biblioteca',
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: FutureBuilder<List<String>>(
                                            future: MusicService.getLocalMusicFiles(),
                                            builder: (context, snapshot) {
                                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                                return const Center(
                                                  child: Text(
                                                    'No hay canciones\ndisponibles',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: WavyTheme.textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                );
                                              }
                                              
                                              return ListView.builder(
                                                itemCount: snapshot.data!.length,
                                                itemBuilder: (context, index) {
                                                  final assetPath = snapshot.data![index];
                                                  final fileName = assetPath.split('/').last;
                                                  final nameWithoutExt = fileName.split('.').first;
                                                  
                                                  return ListTile(
                                                    dense: true,
                                                    selected: _selectedSong == assetPath,
                                                    selectedTileColor: WavyTheme.primaryRed.withOpacity(0.2),
                                                    leading: Icon(
                                                      _selectedSong == assetPath ? Icons.play_arrow : Icons.music_note,
                                                      color: _selectedSong == assetPath ? WavyTheme.primaryRed : WavyTheme.textSecondary,
                                                      size: 16,
                                                    ),
                                                    title: Text(
                                                      nameWithoutExt,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: _selectedSong == assetPath ? FontWeight.bold : FontWeight.normal,
                                                        color: _selectedSong == assetPath ? WavyTheme.primaryRed : WavyTheme.textPrimary,
                                                      ),
                                                    ),
                                                    onTap: () async {
                                                      setState(() {
                                                        _selectedSong = assetPath;
                                                      });
                                                      
                                                      // Update track provider immediately
                                                      trackProvider.updateCurrentTrack(
                                                        nameWithoutExt,
                                                        'Artista Local',
                                                      );
                                                      
                                                      // Play music directly with MusicService
                                                      await MusicService.playLocalMusic(
                                                        assetPath,
                                                        nameWithoutExt,
                                                        'Artista Local',
                                                        isStreaming: true,
                                                      );
                                                    },
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    // Music player fixed at bottom for emisor
                    if (_currentRole == UserRole.emisor && waveProvider.currentWave != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: WavyTheme.cardBackground,
                            border: Border(
                              top: BorderSide(
                                color: WavyTheme.primaryRed.withOpacity(0.3),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () async {
                                  if (_isPlaying) {
                                    await MusicService.pauseMusic();
                                  } else {
                                    await MusicService.resumeMusic();
                                  }
                                },
                                icon: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: WavyTheme.primaryRed,
                                  size: 32,
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: WavyTheme.primaryRed,
                                    inactiveTrackColor: WavyTheme.primaryRed.withValues(alpha: 0.3),
                                    thumbColor: WavyTheme.primaryRed,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    trackHeight: 3,
                                  ),
                                  child: Slider(
                                    value: _totalDuration.inMilliseconds > 0
                                        ? _currentPosition.inMilliseconds.toDouble()
                                        : 0.0,
                                    max: _totalDuration.inMilliseconds.toDouble(),
                                    onChanged: (value) async {
                                      final position = Duration(milliseconds: value.toInt());
                                      await MusicService.audioPlayer.seek(position);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(_currentPosition),
                                style: const TextStyle(
                                  color: WavyTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInWaveView(BuildContext context, WaveProvider waveProvider) {
    return Column(
      children: [
        WaveInfoCard(wave: waveProvider.currentWave!),
        const SizedBox(height: 16),
        // Show track list ONLY for listeners who joined a wave
        if (_currentRole == UserRole.oyente) ...[
          // Simplified audio widget without hybrid service dependency
          const AudioStreamWidget(),
          const SizedBox(height: 16),
          Expanded(
            child: Consumer<TrackProvider>(
              builder: (context, trackProvider, child) {
                // Initialize track provider only once when joining a wave
                if (waveProvider.currentWave != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    trackProvider.initialize(waveProvider.currentWave!.id);
                  });
                }
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: const Text(
                    'Lista de tracks',
                    style: TextStyle(color: WavyTheme.textSecondary),
                  ),
                );
              },
            ),
          ),
        ],
        // For emisor, show music controls when in wave
        if (_currentRole == UserRole.emisor)
          Expanded(
            child: Consumer<TrackProvider>(
              builder: (context, trackProvider, child) {
                // Initialize track provider for emisor
                if (waveProvider.currentWave != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    trackProvider.initialize(waveProvider.currentWave!.id);
                  });
                }
                
                return Column(
                  children: [
                    // Main transmission info
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: WavyTheme.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Streaming status display
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: waveProvider.isStreaming 
                                  ? WavyTheme.primaryRed.withValues(alpha: 0.1)
                                  : WavyTheme.textSecondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  waveProvider.isStreaming 
                                      ? Icons.radio_button_checked 
                                      : Icons.radio_button_unchecked,
                                  color: waveProvider.isStreaming 
                                      ? WavyTheme.primaryRed 
                                      : WavyTheme.textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  waveProvider.isStreaming 
                                      ? 'TRANSMITIENDO EN VIVO' 
                                      : 'INICIANDO TRANSMISIÓN...',
                                  style: TextStyle(
                                    color: waveProvider.isStreaming 
                                        ? WavyTheme.primaryRed 
                                        : WavyTheme.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Listeners count
                          if (waveProvider.isStreaming) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: WavyTheme.cardBackground,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: WavyTheme.primaryRed.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.people,
                                    color: WavyTheme.primaryRed,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${waveProvider.listenersCount} oyentes',
                                    style: const TextStyle(
                                      color: WavyTheme.primaryRed,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // Current track info
                          if (trackProvider.currentTrack != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              trackProvider.currentTrack!.title,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              trackProvider.currentTrack!.artist,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: WavyTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Played tracks section
                    if (trackProvider.playedTracks.isNotEmpty)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: WavyTheme.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: WavyTheme.primaryRed.withOpacity(0.1),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.history,
                                      color: WavyTheme.primaryRed,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Reproducidas',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: trackProvider.playedTracks.length,
                                  itemBuilder: (context, index) {
                                    final track = trackProvider.playedTracks[index];
                                    return ListTile(
                                      dense: true,
                                      leading: Icon(
                                        track.isCurrent ? Icons.play_arrow : Icons.music_note,
                                        color: track.isCurrent ? WavyTheme.primaryRed : WavyTheme.textSecondary,
                                        size: 20,
                                      ),
                                      title: Text(
                                        track.title,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: track.isCurrent ? FontWeight.bold : FontWeight.normal,
                                          color: track.isCurrent ? WavyTheme.primaryRed : WavyTheme.textPrimary,
                                        ),
                                      ),
                                      subtitle: Text(
                                        track.artist,
                                        style: const TextStyle(
                                          color: WavyTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      onTap: () {
                                        trackProvider.updateCurrentTrack(
                                          track.title,
                                          track.artist,
                                          duration: track.duration,
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 80), // Space for bottom player
                  ],
                );
              },
            ),
          ),
        // Leave wave button - only for oyentes
        if (_currentRole == UserRole.oyente)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  waveProvider.leaveWave();
                  // Clear tracks when leaving
                  context.read<TrackProvider>().clearTracks();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: WavyTheme.textSecondary,
                ),
                child: const Text(
                  'Salir de Wave',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildEmisorView(BuildContext context, WaveProvider waveProvider) {
    return Column(
      children: [
        const Spacer(),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: WavyTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.radio,
                size: 60,
                color: WavyTheme.primaryRed,
              ),
              const SizedBox(height: 16),
              Text(
                waveProvider.currentWave != null 
                    ? 'Transmitiendo en vivo'
                    : 'Preparando transmisión...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const Spacer(),
      ],
    );
  }
  
  Widget _buildOyenteView(BuildContext context, WaveProvider waveProvider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Waves en línea',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: WaveList(
            waves: waveProvider.onlineWaves,
            onWaveTap: (wave) {
              // Al unirse a un wave, iniciar HLS automáticamente
              waveProvider.joinWave(wave.id);
              _startHlsForWave(wave.id);
            },
          ),
        ),
      ],
    );
  }
  
  void _startHlsForWave(String waveId) async {
    _hybridService = HybridAudioService();
    try {
      await _hybridService!.joinRoom(waveId, 'oyente-${DateTime.now().millisecondsSinceEpoch}', isHost: false);
      print('🌊 Joined HLS for wave: $waveId');
    } catch (e) {
      print('❌ Error joining HLS for wave: $e');
    }
  }
}