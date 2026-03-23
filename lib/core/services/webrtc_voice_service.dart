import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/track.dart';
import '../socket/socket_service.dart';

class P2PProgramTrack {
  final String title;
  final String localPath;
  final String fromUserId;
  final String transferId;

  P2PProgramTrack({
    required this.title,
    required this.localPath,
    required this.fromUserId,
    required this.transferId,
  });
}

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

class _IncomingProgramBuffer {
  final String transferId;
  final String title;
  final String fromUserId;
  final List<int> bytes = <int>[];
  bool isClosed = false;

  _IncomingProgramBuffer({
    required this.transferId,
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
  final Map<String, RTCDataChannel> _programChannels = {};
  final Map<String, List<RTCIceCandidate>> _pendingIceCandidates = {};
  final Set<String> _remoteDescriptionReadyPeers = <String>{};
  final Map<String, int> _offerRetryEpochMs = {};
  final Map<String, _IncomingProgramBuffer> _incomingProgramBuffers = {};
  final Map<String, String> _activeIncomingTransferByPeer = {};
  final StreamController<P2PProgramTrack> _incomingProgramController =
      StreamController<P2PProgramTrack>.broadcast();
  HttpServer? _programRelayServer;
  int? _programRelayPort;
  bool _isStartingProgramRelay = false;

  MediaStream? _localStream;
  bool _micEnabled = false;
  bool _initialized = false;
  bool _handlersRegistered = false;

  bool _isHost = false;
  bool _isPreparingLocalStream = false;
  String? _hostUserId;

  int _broadcastGeneration = 0;
  String? _currentOutgoingTransferId;
  Track? _currentLocalProgramTrack;

  static const int _programChunkSize = 12 * 1024;

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
    } else {
      await _ensureProgramRelayServer();
    }

    if (!isHost && hostUserId != null) {
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

    for (final channel in _programChannels.values) {
      channel.close();
    }
    _programChannels.clear();

    for (final transferId in _incomingProgramBuffers.keys.toList()) {
      await _cleanupIncomingTransfer(transferId);
    }
    _activeIncomingTransferByPeer.clear();

    await _programRelayServer?.close(force: true);
    _programRelayServer = null;
    _programRelayPort = null;

    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    _localStream = null;

    _initialized = false;
    _micEnabled = false;
    _isHost = false;
    _hostUserId = null;
    _currentOutgoingTransferId = null;
    _currentLocalProgramTrack = null;
    _pendingIceCandidates.clear();
    _remoteDescriptionReadyPeers.clear();
    _offerRetryEpochMs.clear();

    if (_handlersRegistered) {
      _unregisterSignalingHandlers();
      _handlersRegistered = false;
    }
  }

  bool get isMicEnabled => _micEnabled;
  bool get isInitialized => _initialized;
  int get peerCount => _pcs.length;
  Stream<P2PProgramTrack> get incomingProgramStream => _incomingProgramController.stream;
  Stream<P2PLocalTrack> get incomingTrackStream =>
      _incomingProgramController.stream.map(
        (event) => P2PLocalTrack(
          title: event.title,
          localPath: event.localPath,
          fromUserId: event.fromUserId,
          transferId: event.transferId,
        ),
      );

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

  Future<bool> broadcastTrack(Track track) async {
    if (!_isHost) return false;
    final openChannels = _programChannels.values
        .where((c) => c.state == RTCDataChannelState.RTCDataChannelOpen)
        .toList();
    if (openChannels.isEmpty) return false;

    return _sendTrackToChannels(track, openChannels);
  }

  Future<bool> _sendTrackToChannels(
    Track track,
    List<RTCDataChannel> channels,
  ) async {
    final source = track.url;
    if (source == null || source.isEmpty) return false;

    final stream = await _openTrackByteStream(source);
    if (stream == null) return false;

    final transferId =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 31)}';

    _broadcastGeneration += 1;
    final generation = _broadcastGeneration;

    if (_currentOutgoingTransferId != null) {
      for (final ch in channels) {
        _sendProgramJson(ch, {
          't': 'program_stop',
          'id': _currentOutgoingTransferId,
        });
      }
    }
    _currentOutgoingTransferId = transferId;

    final startedAt = DateTime.now().millisecondsSinceEpoch;
    for (final ch in channels) {
      _sendProgramJson(ch, {
        't': 'program_start',
        'id': transferId,
        'title': track.title,
        'startedAt': startedAt,
      });
    }

    var sentBytes = 0;
    var firstChunkAt = DateTime.now().millisecondsSinceEpoch;

    await for (final rawChunk in stream) {
      if (generation != _broadcastGeneration) {
        return false;
      }

      var offset = 0;
      while (offset < rawChunk.length) {
        final end = min(offset + _programChunkSize, rawChunk.length);
        final piece = rawChunk.sublist(offset, end);
        offset = end;

        final payload = {
          't': 'program_chunk',
          'id': transferId,
          'd': base64Encode(piece),
        };

        for (final ch in channels) {
          _sendProgramJson(ch, payload);
          await _applyDynamicPacing(
            channel: ch,
            sentBytes: sentBytes,
            firstChunkAt: firstChunkAt,
          );
        }

        sentBytes += piece.length;
      }
    }

    for (final ch in channels) {
      _sendProgramJson(ch, {
        't': 'program_end',
        'id': transferId,
      });
    }

    return true;
  }

  Future<bool> broadcastLocalTrack(String localPath, String title) {
    _currentLocalProgramTrack = Track(
      title: title,
      artist: 'DJ',
      url: localPath,
      isCurrent: true,
      playedAt: DateTime.now(),
    );
    return broadcastTrack(_currentLocalProgramTrack!);
  }

  Future<Stream<List<int>>?> _openTrackByteStream(String source) async {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(source));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        client.close(force: true);
        return null;
      }
      return response;
    }

    final file = File(source);
    if (!await file.exists()) return null;
    return file.openRead();
  }

  Future<void> _ensureProgramRelayServer() async {
    if (_programRelayServer != null || _isStartingProgramRelay) return;

    _isStartingProgramRelay = true;
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _programRelayServer = server;
      _programRelayPort = server.port;

      server.listen((request) async {
        try {
          final segments = request.uri.pathSegments;
          if (segments.length < 2 || segments[0] != 'program') {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            return;
          }

          final transferId = segments[1].replaceAll('.mp3', '');
          final buffer = _incomingProgramBuffers[transferId];
          if (buffer == null) {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            return;
          }
          request.response.headers.contentType = ContentType('audio', 'mpeg');
          request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');

          var cursor = 0;
          while (true) {
            final available = buffer.bytes.length;
            if (cursor < available) {
              request.response.add(buffer.bytes.sublist(cursor, available));
              cursor = available;
              continue;
            }

            if (buffer.isClosed) {
              break;
            }

            await Future.delayed(const Duration(milliseconds: 35));
          }

          await request.response.close();
        } catch (_) {
          try {
            request.response.statusCode = HttpStatus.internalServerError;
            await request.response.close();
          } catch (_) {}
        }
      });
    } finally {
      _isStartingProgramRelay = false;
    }
  }

  Future<void> _applyDynamicPacing({
    required RTCDataChannel channel,
    required int sentBytes,
    required int firstChunkAt,
  }) async {
    int bufferedAmount;
    try {
      bufferedAmount = channel.bufferedAmount ?? 0;
    } catch (_) {
      bufferedAmount = 0;
    }

    if (bufferedAmount > 1024 * 1024) {
      await Future.delayed(const Duration(milliseconds: 80));
      return;
    }
    if (bufferedAmount > 512 * 1024) {
      await Future.delayed(const Duration(milliseconds: 40));
      return;
    }
    if (bufferedAmount > 256 * 1024) {
      await Future.delayed(const Duration(milliseconds: 20));
      return;
    }

    final elapsedMs = DateTime.now().millisecondsSinceEpoch - firstChunkAt;
    if (elapsedMs <= 0) return;

    final currentBps = (sentBytes * 1000) ~/ elapsedMs;
    if (currentBps > 220000) {
      await Future.delayed(const Duration(milliseconds: 8));
    }
  }

  void _registerSignalingHandlers() {
    if (_handlersRegistered) return;
    _handlersRegistered = true;

    _socket.on('webrtc_offer_requested', (data) async {
      final fromUserId = data['fromUserId']?.toString();
      if (fromUserId == null || !_isHost) return;
      await _createAndSendOffer(fromUserId);
    });

    _socket.on('user_joined_room', (data) async {
      final userId = data['userId']?.toString();
      final isHost = data['isHost'] == true;
      if (!_isHost || isHost || userId == null) return;
      await _createAndSendOffer(userId);
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
      _remoteDescriptionReadyPeers.add(fromUserId);
      await _flushPendingIceCandidates(fromUserId);
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
      final candidate = RTCIceCandidate(
        candMap['candidate'],
        candMap['sdpMid'],
        candMap['sdpMLineIndex'],
      );
      if (pc == null || !_remoteDescriptionReadyPeers.contains(fromUserId)) {
        _pendingIceCandidates.putIfAbsent(fromUserId, () => <RTCIceCandidate>[]).add(candidate);
        return;
      }

      try {
        await pc.addCandidate(candidate);
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
    _socket.off('user_joined_room');
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
        'program',
        RTCDataChannelInit()
          ..ordered = true,
      );
      _registerProgramChannel(peerId, channel);
    }

    pc.onDataChannel = (channel) {
      _registerProgramChannel(peerId, channel);
    };

    pc.onConnectionState = (state) {
      debugPrint('🎙️ PC[$peerId] connectionState=$state');
      if (!_isHost &&
          (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
              state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) &&
          _hostUserId == peerId) {
        _scheduleOfferRetry(peerId);
      }
    };

    pc.onIceConnectionState = (state) {
      debugPrint('🎙️ PC[$peerId] iceConnectionState=$state');
      if (!_isHost &&
          (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
              state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) &&
          _hostUserId == peerId) {
        _scheduleOfferRetry(peerId);
      }
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
    _remoteDescriptionReadyPeers.add(peerId);
    await _flushPendingIceCandidates(peerId);

    final answer = await pc.createAnswer({});
    final optimizedAnswerSdp = _optimizeAudioSdp(answer.sdp);
    await pc.setLocalDescription(answer);

    _socket.emit('webrtc_answer', {
      'targetUserId': peerId,
      'sdp': {'sdp': optimizedAnswerSdp, 'type': answer.type},
    });
  }

  void _closePc(String peerId) {
    _programChannels.remove(peerId)?.close();
    _pcs.remove(peerId)?.close();
    _remoteDescriptionReadyPeers.remove(peerId);
    _pendingIceCandidates.remove(peerId);

    final incomingTransfer = _activeIncomingTransferByPeer.remove(peerId);
    if (incomingTransfer != null) {
      _cleanupIncomingTransfer(incomingTransfer);
    }
  }

  Future<void> _flushPendingIceCandidates(String peerId) async {
    final pc = _pcs[peerId];
    final pending = _pendingIceCandidates.remove(peerId);
    if (pc == null || pending == null || pending.isEmpty) return;

    for (final candidate in pending) {
      try {
        await pc.addCandidate(candidate);
      } catch (_) {}
    }
  }

  void _scheduleOfferRetry(String peerId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _offerRetryEpochMs[peerId] ?? 0;
    if (now - last < 2500) return;
    _offerRetryEpochMs[peerId] = now;

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!_isHost && _hostUserId == peerId && !_hasUsableConnection(peerId)) {
        _requestOffer(peerId);
      }
    });
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
          'noiseSuppression': false,
          'autoGainControl': true,
          'googEchoCancellation': true,
          'googAutoGainControl': true,
          'googAutoGainControl2': true,
          'googNoiseSuppression': false,
          'googNoiseSuppression2': false,
          'googHighpassFilter': true,
          'channelCount': 1,
          'sampleRate': 48000,
          'sampleSize': 16,
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
        encodings[0].maxBitrate = 192000;
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
          'maxaveragebitrate=192000',
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
          '${fmtpPrefix}stereo=1;sprop-stereo=1;useinbandfec=1;cbr=1;maxaveragebitrate=192000;ptime=10',
        );
      }
    }

    return lines.join('\r\n');
  }

  void _registerProgramChannel(String peerId, RTCDataChannel channel) {
    _programChannels[peerId] = channel;

    channel.onDataChannelState = (state) async {
      debugPrint('🎵 Program channel[$peerId] state=$state');
      if (_isHost &&
          state == RTCDataChannelState.RTCDataChannelOpen &&
          _currentLocalProgramTrack != null) {
        await _sendTrackToChannels(_currentLocalProgramTrack!, [channel]);
      }
    };

    channel.onMessage = (message) async {
      try {
        final data = jsonDecode(message.text) as Map<String, dynamic>;
        final type = data['t']?.toString();
        final transferId = data['id']?.toString();
        if (type == null || transferId == null) return;

        if (type == 'program_stop') {
          await _cleanupIncomingTransfer(transferId);
          return;
        }

        if (type == 'program_start') {
          await _ensureProgramRelayServer();
          final previousTransfer = _activeIncomingTransferByPeer[peerId];
          if (previousTransfer != null && previousTransfer != transferId) {
            await _cleanupIncomingTransfer(previousTransfer);
          }

          final relayPort = _programRelayPort;
          if (relayPort == null) return;

          _incomingProgramBuffers[transferId] = _IncomingProgramBuffer(
            transferId: transferId,
            title: data['title']?.toString() ?? 'Track',
            fromUserId: peerId,
          );
          _activeIncomingTransferByPeer[peerId] = transferId;

          _incomingProgramController.add(
            P2PProgramTrack(
              title: data['title']?.toString() ?? 'Track',
              localPath: 'http://127.0.0.1:$relayPort/program/$transferId.mp3',
              fromUserId: peerId,
              transferId: transferId,
            ),
          );
          return;
        }

        final buffer = _incomingProgramBuffers[transferId];
        if (buffer == null) return;

        if (type == 'program_chunk') {
          final encoded = data['d']?.toString();
          if (encoded == null || encoded.isEmpty) return;

          final chunkBytes = base64Decode(encoded);
          buffer.bytes.addAll(chunkBytes);
          return;
        }

        if (type == 'program_end') {
          buffer.isClosed = true;

          Future.delayed(const Duration(seconds: 20), () {
            _incomingProgramBuffers.remove(transferId);
          });
          _activeIncomingTransferByPeer.removeWhere((_, value) => value == transferId);
        }
      } catch (e) {
        debugPrint('⚠️ Program DataChannel parse error: $e');
      }
    };
  }

  Future<void> _cleanupIncomingTransfer(String transferId) async {
    final buffer = _incomingProgramBuffers.remove(transferId);
    if (buffer == null) return;

    buffer.isClosed = true;

    _activeIncomingTransferByPeer.removeWhere((_, value) => value == transferId);
  }

  void _sendProgramJson(RTCDataChannel channel, Map<String, dynamic> payload) {
    channel.send(RTCDataChannelMessage(jsonEncode(payload)));
  }
}
