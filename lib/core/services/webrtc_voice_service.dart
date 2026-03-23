import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../socket/socket_service.dart';

class P2PLocalTrack {
  final String title;
  final String localPath;
  final String fromUserId;

  P2PLocalTrack({
    required this.title,
    required this.localPath,
    required this.fromUserId,
  });
}

class _IncomingTrackBuffer {
  final String title;
  final String fromUserId;
  final BytesBuilder bytes = BytesBuilder(copy: false);

  _IncomingTrackBuffer({
    required this.title,
    required this.fromUserId,
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
  final StreamController<P2PLocalTrack> _incomingTrackController =
      StreamController<P2PLocalTrack>.broadcast();

  MediaStream? _localStream;
  bool _micEnabled = false;
  bool _initialized = false;
  bool _handlersRegistered = false;

  bool _isHost = false;
  bool _isPreparingLocalStream = false;
  String? _hostUserId;

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

    debugPrint('🎙️ WebRTCVoiceService initialized – room=$roomId host=$isHost');
  }

  Future<void> dispose() async {
    for (final pc in _pcs.values) {
      pc.close();
    }
    _pcs.clear();
    _musicChannels.clear();
    _incomingTrackBuffers.clear();

    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    _localStream = null;

    _initialized = false;
    _micEnabled = false;
    _isHost = false;
    _hostUserId = null;

    if (_handlersRegistered) {
      _unregisterSignalingHandlers();
      _handlersRegistered = false;
    }
  }

  Future<void> enableMicrophone() async {
    if (_micEnabled) return;
    await _prepareLocalStream(prewarmMuted: false);

    for (final t in _localStream!.getAudioTracks()) {
      t.enabled = true;
    }
    _micEnabled = true;
    _socket.emit('mic_started', {});
  }

  Future<void> disableMicrophone() async {
    if (!_micEnabled) return;
    for (final t in _localStream?.getAudioTracks() ?? []) {
      t.enabled = false;
    }
    _micEnabled = false;
    _socket.emit('mic_stopped', {});
  }

  bool get isMicEnabled => _micEnabled;
  bool get isInitialized => _initialized;
  int get peerCount => _pcs.length;
  Stream<P2PLocalTrack> get incomingTrackStream => _incomingTrackController.stream;

  Future<bool> broadcastLocalTrack(String localPath, String title) async {
    if (!_isHost) return false;

    final openChannels = _musicChannels.entries
        .where((entry) => entry.value.state == RTCDataChannelState.RTCDataChannelOpen)
        .toList();
    if (openChannels.isEmpty) return false;

    final file = File(localPath);
    if (!await file.exists()) return false;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return false;

    final transferId =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 31)}';
    const chunkSize = 12 * 1024;
    final totalChunks = (bytes.length / chunkSize).ceil();

    for (final entry in openChannels) {
      _sendDataJson(entry.value, {
        't': 'track_start',
        'id': transferId,
        'title': title,
        'size': bytes.length,
        'chunks': totalChunks,
      });
    }

    for (var i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = min(start + chunkSize, bytes.length);
      final payload = {
        't': 'track_chunk',
        'id': transferId,
        'i': i,
        'd': base64Encode(bytes.sublist(start, end)),
      };
      for (final entry in openChannels) {
        _sendDataJson(entry.value, payload);
      }
      if (i % 8 == 0) {
        await Future.delayed(const Duration(milliseconds: 2));
      }
    }

    for (final entry in openChannels) {
      _sendDataJson(entry.value, {'t': 'track_end', 'id': transferId});
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
      final hId = data['hostUserId']?.toString();
      if (hId != null) _hostUserId = hId;
      if (!_isHost && _hostUserId != null) {
        if (_hasUsableConnection(_hostUserId!)) return;
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
      final uid = data['userId']?.toString();
      if (uid != null) _closePc(uid);
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
      final dataChannel = await pc.createDataChannel(
        'music',
        RTCDataChannelInit()
          ..ordered = true
          ..maxRetransmits = 5,
      );
      _registerMusicChannel(peerId, dataChannel);
    }

    pc.onDataChannel = (channel) {
      _registerMusicChannel(peerId, channel);
    };

    pc.onIceCandidate = (c) {
      if (c.candidate != null) {
        _socket.emit('webrtc_ice_candidate', {
          'targetUserId': peerId,
          'candidate': {
            'candidate': c.candidate,
            'sdpMid': c.sdpMid,
            'sdpMLineIndex': c.sdpMLineIndex,
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
      for (final t in _localStream!.getAudioTracks()) {
        final sender = await pc.addTrack(t, _localStream!);
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
      for (final t in stream.getAudioTracks()) {
        t.enabled = !prewarmMuted;
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
      final idx = lines.indexWhere((l) => l.startsWith('a=rtpmap:$opusPt'));
      if (idx != -1) {
        lines.insert(idx + 1,
            '${fmtpPrefix}stereo=1;sprop-stereo=1;useinbandfec=1;cbr=1;maxaveragebitrate=128000;ptime=10');
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
        if (transferId == null || type == null) return;

        if (type == 'track_start') {
          _incomingTrackBuffers[transferId] = _IncomingTrackBuffer(
            title: data['title']?.toString() ?? 'Track',
            fromUserId: peerId,
          );
          return;
        }

        final buffer = _incomingTrackBuffers[transferId];
        if (buffer == null) return;

        if (type == 'track_chunk') {
          final encoded = data['d']?.toString();
          if (encoded == null || encoded.isEmpty) return;
          buffer.bytes.add(base64Decode(encoded));
          return;
        }

        if (type == 'track_end') {
          final bytes = buffer.bytes.takeBytes();
          final filePath =
              '${Directory.systemTemp.path}/wavy_p2p_${DateTime.now().millisecondsSinceEpoch}.mp3';
          final out = File(filePath);
          await out.writeAsBytes(bytes, flush: true);

          _incomingTrackController.add(
            P2PLocalTrack(
              title: buffer.title,
              localPath: filePath,
              fromUserId: buffer.fromUserId,
            ),
          );
          _incomingTrackBuffers.remove(transferId);
        }
      } catch (e) {
        debugPrint('⚠️ DataChannel parse error: $e');
      }
    };
  }

  void _sendDataJson(RTCDataChannel channel, Map<String, dynamic> payload) {
    channel.send(RTCDataChannelMessage(jsonEncode(payload)));
  }
}
