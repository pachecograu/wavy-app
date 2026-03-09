import 'package:flutter/material.dart';
import '../core/services/hybrid_audio_service.dart';
import 'package:uuid/uuid.dart';

class HybridAudioPlayerDebug extends StatefulWidget {
  const HybridAudioPlayerDebug({
    super.key,
    required this.roomId,
  });

  final String roomId;

  @override
  State<HybridAudioPlayerDebug> createState() => _HybridAudioPlayerDebugState();
}

class _HybridAudioPlayerDebugState extends State<HybridAudioPlayerDebug> {
  final HybridAudioService _hybridService = HybridAudioService();
  final String _userId = const Uuid().v4();
  double _musicVolume = 0.8;
  bool _isLoading = false;
  String _statusMessage = 'Inicializando...';

  @override
  void initState() {
    super.initState();
    _joinRoom();
  }

  Future<void> _joinRoom() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Conectando a sala...';
    });
    
    try {
      await _hybridService.joinRoom(widget.roomId, _userId);
      setState(() {
        _statusMessage = 'Conectado exitosamente';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Room: ${widget.roomId}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage),
                ],
              ),
            )
          : Column(
              children: [
                _buildStatusSection(),
                const Divider(),
                _buildMusicSection(),
                const Divider(),
                _buildVoiceSection(),
                const Divider(),
                _buildParticipantsSection(),
              ],
            ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('Estado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Usuario: ${_userId.substring(0, 8)}...'),
            Text('Sala: ${widget.roomId}'),
            Text('Estado: $_statusMessage'),
            Text('En sala: ${_hybridService.isInRoom ? "Sí" : "No"}'),
          ],
        ),
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
            const SizedBox(height: 8),
            Text('Estado: ${_hybridService.isMusicPlaying ? "Reproduciendo" : "Detenido"}'),
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
            const SizedBox(height: 8),
            Text('Conectado: ${_hybridService.isVoiceConnected ? "Sí" : "No"}'),
            Text('Micrófono: ${_hybridService.isMicEnabled ? "Activo" : "Inactivo"}'),
            Text('Esperando token: ${_hybridService.isWaitingForVoiceToken ? "Sí" : "No"}'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: (_hybridService.isMicEnabled || _hybridService.isWaitingForVoiceToken) ? null : _requestMic,
                  icon: const Icon(Icons.mic),
                  label: Text(_hybridService.isWaitingForVoiceToken ? 'Esperando...' : 'Pedir Mic'),
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

  Future<void> _requestMic() async {
    try {
      await _hybridService.requestMicrophone();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al pedir micrófono: $e')),
      );
    }
  }

  Future<void> _releaseMic() async {
    try {
      await _hybridService.releaseMicrophone();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al soltar micrófono: $e')),
      );
    }
  }

  @override
  void dispose() {
    _hybridService.leaveRoom();
    super.dispose();
  }
}