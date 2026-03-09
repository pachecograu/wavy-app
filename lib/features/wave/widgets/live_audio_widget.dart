import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/theme/wavy_theme.dart';
import '../providers/wave_provider.dart';

class LiveAudioWidget extends StatefulWidget {
  const LiveAudioWidget({super.key});

  @override
  State<LiveAudioWidget> createState() => _LiveAudioWidgetState();
}

class _LiveAudioWidgetState extends State<LiveAudioWidget>
    with TickerProviderStateMixin {
  final SocketService _socketService = SocketService();
  String _currentSong = '';
  bool _isReceivingAudio = false;
  int _audioPacketsReceived = 0;
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _setupAudioListeners();
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));
  }

  void _setupAudioListeners() {
    // Usar el sistema de waves para audio en tiempo real
    _socketService.onSongStarted((data) {
      if (mounted) {
        final songData = data['songData'];
        if (songData != null) {
          final title = songData['title']?.toString() ?? 'Sin título';
          final artist = songData['artist']?.toString() ?? 'Artista desconocido';
          setState(() {
            _currentSong = '$title - $artist';
            _isReceivingAudio = true;
          });
          _waveController.repeat();
        }
      }
    });

    _socketService.onReceiveLiveAudio((data) {
      if (mounted && data['audioBuffer'] != null) {
        setState(() {
          _audioPacketsReceived++;
          _isReceivingAudio = true;
        });
      }
    });

    _socketService.onSongControlUpdate((data) {
      if (mounted) {
        final action = data['action'];
        if (action != null) {
          setState(() {
            _isReceivingAudio = action == 'play';
          });
          
          if (_isReceivingAudio) {
            _waveController.repeat();
          } else {
            _waveController.stop();
          }
        }
      }
    });

    _socketService.onAudioData((data) {
      if (mounted) {
        setState(() {
          _audioPacketsReceived++;
          _isReceivingAudio = true;
        });
      }
    });

    _socketService.onReceiveAudioChunk((data) {
      if (mounted) {
        setState(() {
          _audioPacketsReceived++;
          _isReceivingAudio = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WaveProvider>(
      builder: (context, waveProvider, child) {
        if (waveProvider.currentWave == null || waveProvider.isOwner) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WavyTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isReceivingAudio 
                  ? Colors.green.withOpacity(0.5)
                  : WavyTheme.primaryRed.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _waveAnimation,
                    builder: (context, child) {
                      return Icon(
                        Icons.music_note,
                        color: _isReceivingAudio 
                            ? Colors.green.withOpacity(0.5 + 0.5 * _waveAnimation.value)
                            : Colors.grey,
                        size: 24,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isReceivingAudio ? 'RECIBIENDO AUDIO' : 'SIN AUDIO',
                      style: TextStyle(
                        color: _isReceivingAudio ? Colors.green : Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isReceivingAudio ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isReceivingAudio ? 'LIVE' : 'OFF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (_currentSong.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Reproduciendo: $_currentSong',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: WavyTheme.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Paquetes: $_audioPacketsReceived',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (_isReceivingAudio)
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'EN VIVO',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}