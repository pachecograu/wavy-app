import 'package:flutter/material.dart';
import '../core/services/hybrid_audio_service.dart';
import 'package:uuid/uuid.dart';

class HybridAudioPlayer extends StatefulWidget {
  final String roomId;
  
  const HybridAudioPlayer({
    super.key,
    required this.roomId,
  });

  @override
  State<HybridAudioPlayer> createState() => _HybridAudioPlayerState();
}

class _HybridAudioPlayerState extends State<HybridAudioPlayer> {
  final HybridAudioService _hybridService = HybridAudioService();
  final String _userId = const Uuid().v4();
  double _musicVolume = 0.8;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _joinRoom();
  }

  Future<void> _joinRoom() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _hybridService.joinRoom(widget.roomId, _userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Room: ${widget.roomId}'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Música (HLS Stream)
                _buildMusicSection(),
                const Divider(),
                // Streaming de Bits
                _buildBitsStreamingSection(),
                const Divider(),
                // Voz (WebRTC)
                _buildVoiceSection(),
                const Divider(),
                // Participantes
                _buildParticipantsSection(),
              ],
            ),
    );
  }

  Widget _buildMusicSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.music_note, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('Música (HLS)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Icon(
                  _hybridService.isMusicPlaying ? Icons.volume_up : Icons.volume_off,
                  color: _hybridService.isMusicPlaying ? Colors.green : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Volumen:'),
                Expanded(
                  child: Slider(
                    value: _musicVolume,
                    onChanged: (value) {
                      setState(() => _musicVolume = value);
                      _hybridService.setMusicVolume(value);
                    },
                  ),
                ),
                Text('${(_musicVolume * 100).round()}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mic, color: Colors.red),
                const SizedBox(width: 8),
                const Text('Voz (WebRTC)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Icon(
                  _hybridService.isVoiceConnected ? Icons.wifi : Icons.wifi_off,
                  color: _hybridService.isVoiceConnected ? Colors.green : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _hybridService.isMicEnabled ? null : _requestMic,
                  icon: const Icon(Icons.mic),
                  label: const Text('Pedir Mic'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _hybridService.isMicEnabled ? _releaseMic : null,
                  icon: const Icon(Icons.mic_off),
                  label: const Text('Soltar Mic'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.people, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Participantes con Voz', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder(
                  stream: _hybridService.participantsStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: Text('Sin participantes con voz'));
                    }
                    
                    final participants = snapshot.data as List;
                    return ListView.builder(
                      itemCount: participants.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text('Participante ${index + 1}'),
                          trailing: const Icon(Icons.mic, color: Colors.green),
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
    );
  }

  Widget _buildBitsStreamingSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.radio,
                  color: _hybridService.isStreamingBits ? Colors.red : Colors.grey,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Streaming de Bits',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Icon(
                  _hybridService.isStreamingBits ? Icons.wifi : Icons.wifi_off,
                  color: _hybridService.isStreamingBits ? Colors.green : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: !_hybridService.isStreamingBits ? _startBitsStreaming : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Bits'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _startAudioStreaming,
                  icon: const Icon(Icons.music_note),
                  label: const Text('Audio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (_hybridService.isStreamingBits) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.radio,
                      color: Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'TRANSMITIENDO BITS EN VIVO',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _startBitsStreaming() {
    _hybridService.startBitsStreaming();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📡 Streaming de bits iniciado')),
      );
    }
  }

  void _startAudioStreaming() {
    _hybridService.startAudioStreaming();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎵 Streaming de audio iniciado')),
      );
    }
  }

  Future<void> _requestMic() async {
    try {
      await _hybridService.requestMicrophone();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al pedir micrófono: $e')),
        );
      }
    }
  }

  Future<void> _releaseMic() async {
    try {
      await _hybridService.releaseMicrophone();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al soltar micrófono: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _hybridService.leaveRoom();
    super.dispose();
  }
}