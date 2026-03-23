import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../socket/socket_service.dart';

class P2PLocalTrack {
  final String title;
  final String localPath;
  final String fromUserId;
  final String transferId;

  P2PLocalTrack({
    required this.title,
    required this.localPath,
    required this.fromUserId,
    required this.transferId,
  });
}

class _IncomingTrackBuffer {
  final String transferId;
  final String title;
  final String fromUserId;
  final String filePath;
  final IOSink sink;

  int bytesReceived = 0;
  bool playbackStarted = false;

  _IncomingTrackBuffer({
    required this.transferId,
    required this.title,
    required this.fromUserId,
    required this.filePath,
    required this.sink,
  });
}

class WebRTCVoiceService {
  static final WebRTCVoiceService _instance = WebRTCVoiceService._internal();
  factory WebRTCVoiceService() => _instance;
  WebRTCVoiceService._internal();

  final SocketService _socket = SocketService();

  final Map<String, RTCPeerConnection> _pcs = {};
  final Map<String, RTCDataChannel> _musicChannels = {};
  final Map<String, _IncomingTrackBuffer> _incomingTrackBuffers = {};
  final Map<String, String> _activeIncomingTransferByPeer = {};
  final StreamController<P2PLocalTrack> _incomingTrackController =
      StreamController<P2PLocalTrack>.broadcast();

  MediaStream? _localStream;
  bool _micEnabled = false;
  bool _initialized = false;
  bool _handlersRegistered = false;

  bool _isHost = false;
  bool _isPreparingLocalStream = false;
  String? _hostUserId;

  int _broadcastGeneration = 0;
  String? _currentOutgoingTransferId;

  static const Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
  };

  Future<void> initialize(
    String roomId,
    String userId, {
    required bool isHost,
    String? hostUserId,
    bool micActive = false,
  }) async {
    if (_initialized) return;

    _initialized = true;
    _isHost = isHost;
    _hostUserId = hostUserId;

    _registerSignalingHandlers();

    if (_isHost) {
      await _prepareLocalStream(prewarmMuted: true);
    }

    if (!isHost && hostUserId != null) {
      debugPrint('🎙️ Listener preconnect – requesting offer from $hostUserId');
      _requestOffer(hostUserId);
      if (micActive) {
        debugPrint('🎙️ Mic already active on join');
      }
    }

    debugPrint('🎙️ WebRTCVoiceService initialized – room=$roomId user=$userId host=$isHost');
  }

  Future<void> dispose() async {
    for (final pc in _pcs.values) {
      pc.close();
    }
    _pcs.clear();

    for (final channel in _musicChannels.values) {
      channel.close();
    }
    _musicChannels.clear();

    for (final transferId in _incomingTrackBuffers.keys.toList()) {
      await _cleanupIncomingTransfer(transferId);
    }
    _activeIncomingTransferByPeer.clear();

    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    _localStream = null;

    _initialized = false;
    _micEnabled = false;
    _isHost = false;
    _hostUserId = null;
    _currentOutgoingTransferId = null;

    if (_handlersRegistered) {
      _unregisterSignalingHandlers();
      _handlersRegistered = false;
    }
  }

  bool get isMicEnabled => _micEnabled;
  bool get isInitialized => _initialized;
  int get peerCount => _pcs.length;
  Stream<P2PLocalTrack> get incomingTrackStream => _incomingTrackController.stream;

  Future<void> enableMicrophone() async {
    if (_micEnabled) return;

    await _prepareLocalStream(prewarmMuted: false);
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = true;
    }

    _micEnabled = true;
    _socket.emit('mic_started', {});
  }

  Future<void> disableMicrophone() async {
    if (!_micEnabled) return;

    for (final track in _localStream?.getAudioTracks() ?? []) {
      track.enabled = false;
    }

    _micEnabled = false;
    _socket.emit('mic_stopped', {});
  }

  Future<bool> broadcastLocalTrack(String localPath, String title) async {
    if (!_isHost) return false;

    final openChannels = _musicChannels.values
        .where((c) => c.state == RTCDataChannelState.RTCDataChannelOpen)
        .toList();
    if (openChannels.isEmpty) return false;

    final file = File(localPath);
    if (!await file.exists()) return false;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return false;

    _broadcastGeneration += 1;
    final generation = _broadcastGeneration;

    if (_currentOutgoingTransferId != null) {
      for (final ch in openChannels) {
        _sendDataJson(ch, {
          't': 'track_stop',
          'id': _currentOutgoingTransferId,
        });
      }
    }

    final transferId =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 31)}';
    _currentOutgoingTransferId = transferId;

    const chunkSize = 12 * 1024;
    final totalChunks = (bytes.length / chunkSize).ceil();

    for (final ch in openChannels) {
      _sendDataJson(ch, {
        't': 'track_start',
        'id': transferId,
        'title': title,
        'size': bytes.length,
        'chunks': totalChunks,
      });
    }

    for (var index = 0; index < totalChunks; index++) {
      if (generation != _broadcastGeneration) {
        return false;
      }

      final start = index * chunkSize;
      final end = min(start + chunkSize, bytes.length);
      final chunkPayload = {
        't': 'track_chunk',
        'id': transferId,
        'i': index,
        'd': base64Encode(bytes.sublist(start, end)),
      };

      for (final ch in openChannels) {
        _sendDataJson(ch, chunkPayload);
      }

      if (index > 24) {
        await Future.delayed(const Duration(milliseconds: 24));
      }
    }

    for (final ch in openChannels) {
      _sendDataJson(ch, {
        't': 'track_end',
        'id': transferId,
      });
    }

    return true;
  }

  void _registerSignalingHandlers() {
    if (_handlersRegistered) return;
    _handlersRegistered = true;

    _socket.on('webrtc_offer_requested', (data) async {
      final fromUserId = data['fromUserId']?.toString();
      if (fromUserId == null || !_isHost) return;
      await _createAndSendOffer(fromUserId);
    });

    _socket.on('webrtc_answer', (data) async {
      final fromUserId = data['fromUserId']?.toString();
      final sdpMap = data['sdp'];
      if (fromUserId == null || sdpMap == null) return;
      final pc = _pcs[fromUserId];
      if (pc == null) return;

      await pc.setRemoteDescription(
        RTCSessionDescription(sdpMap['sdp'], sdpMap['type']),
      );
    });

    _socket.on('mic_started', (data) {
      final host = data['hostUserId']?.toString();
      if (host != null) {
        _hostUserId = host;
      }
      if (!_isHost && _hostUserId != null && !_hasUsableConnection(_hostUserId!)) {
        _requestOffer(_hostUserId!);
      }
    });

    _socket.on('webrtc_offer', (data) async {
      final fromUserId = data['fromUserId']?.toString();
      final sdpMap = data['sdp'];
      if (fromUserId == null || sdpMap == null) return;
      await _handleOffer(fromUserId, sdpMap);
    });

    _socket.on('webrtc_ice_candidate', (data) async {
      final fromUserId = data['fromUserId']?.toString();
      final candMap = data['candidate'];
      if (fromUserId == null || candMap == null) return;
      final pc = _pcs[fromUserId];
      if (pc == null) return;

      try {
        await pc.addCandidate(RTCIceCandidate(
          candMap['candidate'],
          candMap['sdpMid'],
          candMap['sdpMLineIndex'],
        ));
      } catch (_) {}
    });

    _socket.on('webrtc_peer_disconnected', (data) {
      final userId = data['userId']?.toString();
      if (userId != null) {
        _closePc(userId);
      }
    });
  }

  void _unregisterSignalingHandlers() {
    _socket.off('webrtc_offer_requested');
    _socket.off('webrtc_answer');
    _socket.off('mic_started');
    _socket.off('mic_stopped');
    _socket.off('webrtc_offer');
    _socket.off('webrtc_ice_candidate');
    _socket.off('webrtc_peer_disconnected');
  }

  void _requestOffer(String hostUserId) {
    _socket.emit('request_webrtc_offer', {'targetUserId': hostUserId});
  }

  Future<RTCPeerConnection> _buildPc(String peerId) async {
    final pc = await createPeerConnection(_iceConfig);

    if (_isHost) {
      final channel = await pc.createDataChannel(
        'music',
        RTCDataChannelInit()
          ..ordered = true
          ..maxRetransmits = 5,
      );
      _registerMusicChannel(peerId, channel);
    }

    pc.onDataChannel = (channel) {
      _registerMusicChannel(peerId, channel);
    };

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _socket.emit('webrtc_ice_candidate', {
          'targetUserId': peerId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      }
    };

    _pcs[peerId] = pc;
    return pc;
  }

  Future<void> _createAndSendOffer(String listenerId) async {
    if (_hasUsableConnection(listenerId)) return;

    if (_isHost && _localStream == null) {
      await _prepareLocalStream(prewarmMuted: true);
    }

    _closePc(listenerId);
    final pc = await _buildPc(listenerId);

    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        final sender = await pc.addTrack(track, _localStream!);
        await _optimizeSender(sender);
      }
    }

    final offer = await pc.createOffer({});
    final optimizedOfferSdp = _optimizeAudioSdp(offer.sdp);
    await pc.setLocalDescription(offer);

    _socket.emit('webrtc_offer', {
      'targetUserId': listenerId,
      'sdp': {'sdp': optimizedOfferSdp, 'type': offer.type},
    });
  }

  Future<void> _handleOffer(String peerId, Map sdpMap) async {
    _closePc(peerId);
    final pc = await _buildPc(peerId);

    await pc.setRemoteDescription(
      RTCSessionDescription(sdpMap['sdp'], sdpMap['type']),
    );

    final answer = await pc.createAnswer({});
    final optimizedAnswerSdp = _optimizeAudioSdp(answer.sdp);
    await pc.setLocalDescription(answer);

    _socket.emit('webrtc_answer', {
      'targetUserId': peerId,
      'sdp': {'sdp': optimizedAnswerSdp, 'type': answer.type},
    });
  }

  void _closePc(String peerId) {
    _musicChannels.remove(peerId)?.close();
    _pcs.remove(peerId)?.close();

    final incomingTransfer = _activeIncomingTransferByPeer.remove(peerId);
    if (incomingTransfer != null) {
      _cleanupIncomingTransfer(incomingTransfer);
    }
  }

  bool _hasUsableConnection(String peerId) {
    final pc = _pcs[peerId];
    if (pc == null) return false;

    return pc.iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        pc.iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateCompleted ||
        pc.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
  }

  Future<void> _prepareLocalStream({required bool prewarmMuted}) async {
    if (_localStream != null || _isPreparingLocalStream) return;

    _isPreparingLocalStream = true;
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'channelCount': 1,
          'sampleRate': 48000,
          'latency': 0,
        },
        'video': false,
      });

      for (final track in stream.getAudioTracks()) {
        track.enabled = !prewarmMuted;
      }
      _localStream = stream;
    } finally {
      _isPreparingLocalStream = false;
    }
  }

  Future<void> _optimizeSender(RTCRtpSender sender) async {
    try {
      final params = sender.parameters;
      final encodings = params.encodings;
      if (encodings != null && encodings.isNotEmpty) {
        encodings[0].maxBitrate = 128000;
      }
      await sender.setParameters(params);
    } catch (_) {}
  }

  String? _optimizeAudioSdp(String? sdp) {
    if (sdp == null || sdp.isEmpty) return sdp;

    final lines = sdp.split('\r\n');
    String? opusPt;
    for (final line in lines) {
      if (line.startsWith('a=rtpmap:') && line.toLowerCase().contains('opus/48000')) {
        opusPt = line.substring('a=rtpmap:'.length).split(' ').first;
        break;
      }
    }
    if (opusPt == null) return sdp;

    final fmtpPrefix = 'a=fmtp:$opusPt ';
    var hasFmtp = false;

    for (var i = 0; i < lines.length; i++) {
      if (lines[i].startsWith(fmtpPrefix)) {
        hasFmtp = true;
        final existing = lines[i].substring(fmtpPrefix.length);
        final extras = [
          'stereo=1',
          'sprop-stereo=1',
          'useinbandfec=1',
          'cbr=1',
          'maxaveragebitrate=128000',
          'ptime=10',
        ];
        lines[i] = '$fmtpPrefix$existing;${extras.join(';')}';
        break;
      }
    }

    if (!hasFmtp) {
      final idx = lines.indexWhere((line) => line.startsWith('a=rtpmap:$opusPt'));
      if (idx != -1) {
        lines.insert(
          idx + 1,
          '${fmtpPrefix}stereo=1;sprop-stereo=1;useinbandfec=1;cbr=1;maxaveragebitrate=128000;ptime=10',
        );
      }
    }

    return lines.join('\r\n');
  }

  void _registerMusicChannel(String peerId, RTCDataChannel channel) {
    _musicChannels[peerId] = channel;

    channel.onMessage = (message) async {
      try {
        final data = jsonDecode(message.text) as Map<String, dynamic>;
        final type = data['t']?.toString();
        final transferId = data['id']?.toString();
        if (type == null || transferId == null) return;

        if (type == 'track_stop') {
          await _cleanupIncomingTransfer(transferId);
          return;
        }

        if (type == 'track_start') {
          final previousTransfer = _activeIncomingTransferByPeer[peerId];
          if (previousTransfer != null && previousTransfer != transferId) {
            await _cleanupIncomingTransfer(previousTransfer);
          }

          final filePath =
              '${Directory.systemTemp.path}/wavy_p2p_${DateTime.now().millisecondsSinceEpoch}.mp3';
          final sink = File(filePath).openWrite(mode: FileMode.writeOnlyAppend);

          _incomingTrackBuffers[transferId] = _IncomingTrackBuffer(
            transferId: transferId,
            title: data['title']?.toString() ?? 'Track',
            fromUserId: peerId,
            filePath: filePath,
            sink: sink,
          );
          _activeIncomingTransferByPeer[peerId] = transferId;
          return;
        }

        final buffer = _incomingTrackBuffers[transferId];
        if (buffer == null) return;

        if (type == 'track_chunk') {
          final encoded = data['d']?.toString();
          if (encoded == null || encoded.isEmpty) return;
          final chunkBytes = base64Decode(encoded);
          buffer.sink.add(chunkBytes);
          buffer.bytesReceived += chunkBytes.length;

          if (!buffer.playbackStarted && buffer.bytesReceived >= 256 * 1024) {
            buffer.playbackStarted = true;
            _incomingTrackController.add(
              P2PLocalTrack(
                title: buffer.title,
                localPath: buffer.filePath,
                fromUserId: buffer.fromUserId,
                transferId: buffer.transferId,
              ),
            );
          }
          return;
        }

        if (type == 'track_end') {
          await buffer.sink.flush();
          await buffer.sink.close();

          if (!buffer.playbackStarted) {
            _incomingTrackController.add(
              P2PLocalTrack(
                title: buffer.title,
                localPath: buffer.filePath,
                fromUserId: buffer.fromUserId,
                transferId: buffer.transferId,
              ),
            );
          }

          _incomingTrackBuffers.remove(transferId);
        }
      } catch (e) {
        debugPrint('⚠️ DataChannel parse error: $e');
      }
    };
  }

  Future<void> _cleanupIncomingTransfer(String transferId) async {
    final buffer = _incomingTrackBuffers.remove(transferId);
    if (buffer == null) return;

    await buffer.sink.flush();
    await buffer.sink.close();

    _activeIncomingTransferByPeer.removeWhere((_, value) => value == transferId);
  }

  void _sendDataJson(RTCDataChannel channel, Map<String, dynamic> payload) {
    channel.send(RTCDataChannelMessage(jsonEncode(payload)));
  }
}
