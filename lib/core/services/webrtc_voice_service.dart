import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../socket/socket_service.dart';

/// WebRTC P2P voice service.
///
/// Architecture (fan-out from DJ):
/// - DJ (host) creates one RTCPeerConnection per listener.
/// - Listeners request an offer from the DJ; received audio auto-plays
///   through the native WebRTC audio engine.
/// - Backend (hybrid.socket.js) acts as pure signaling relay.
///
/// Signaling flow:
///  1. DJ enables mic → emit `mic_started`
///  2. Listener receives `mic_started` → emit `request_webrtc_offer {targetUserId: djUserId}`
///  3. DJ receives `webrtc_offer_requested {fromUserId}` → creates offer → emits `webrtc_offer`
///  4. Listener receives `webrtc_offer` → creates answer → emits `webrtc_answer`
///  5. ICE candidates exchanged in both directions
///  6. Audio flows ✅
class WebRTCVoiceService {
  static final WebRTCVoiceService _instance = WebRTCVoiceService._internal();
  factory WebRTCVoiceService() => _instance;
  WebRTCVoiceService._internal();

  final SocketService _socket = SocketService();

  /// Active peer connections: peerId → RTCPeerConnection
  final Map<String, RTCPeerConnection> _pcs = {};

  MediaStream? _localStream;
  bool _micEnabled = false;
  bool _initialized = false;
  bool _handlersRegistered = false;

  String? _roomId;
  String? _userId;
  bool _isHost = false;

  /// hostUserId as reported by the backend in hybrid_room_joined / mic_started
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

  // ──────────────────────────────────────────────────────────────────────────
  // Init / Dispose
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> initialize(
    String roomId,
    String userId, {
    required bool isHost,
    String? hostUserId,
    bool micActive = false,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _roomId = roomId;
    _userId = userId;
    _isHost = isHost;
    _hostUserId = hostUserId;

    _registerSignalingHandlers();

    // Listener joins a wave where mic is already active
    if (!isHost && micActive && hostUserId != null) {
      debugPrint('🎙️ Mic already active on join – requesting WebRTC offer from $hostUserId');
      _requestOffer(hostUserId);
    }

    debugPrint('🎙️ WebRTCVoiceService initialized – room=$roomId host=$isHost');
  }

  Future<void> dispose() async {
    for (final pc in _pcs.values) {
      pc.close();
    }
    _pcs.clear();

    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    _localStream = null;

    debugPrint('🎙️ WebRTCVoiceService disposed – room=$_roomId user=$_userId');

    _initialized = false;
    _micEnabled = false;
    _roomId = null;
    _userId = null;
    _isHost = false;
    _hostUserId = null;

    if (_handlersRegistered) {
      _unregisterSignalingHandlers();
      _handlersRegistered = false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> enableMicrophone() async {
    if (_micEnabled) return;
    try {
      _localStream ??= await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'sampleRate': 48000,
        },
        'video': false,
      });

      for (final t in _localStream!.getAudioTracks()) {
        t.enabled = true;
      }
      _micEnabled = true;

      // Notify listeners (only first time they should negotiate).
      // Existing peers stay connected and will receive unmuted audio instantly.
      _socket.emit('mic_started', {});

      debugPrint('🎙️ Microphone enabled – broadcast mic_started');
    } catch (e) {
      debugPrint('❌ enableMicrophone error: $e');
      rethrow;
    }
  }

  Future<void> disableMicrophone() async {
    if (!_micEnabled) return;
    for (final t in _localStream?.getAudioTracks() ?? []) {
      t.enabled = false;
    }
    _micEnabled = false;
    // Keep the WebRTC session alive. Do not close peer connections here.
    // This avoids renegotiation delay on the next mic enable.
    _socket.emit('mic_stopped', {});
    debugPrint('🎙️ Microphone disabled');
  }

  bool get isMicEnabled => _micEnabled;
  bool get isInitialized => _initialized;
  int get peerCount => _pcs.length;

  // ──────────────────────────────────────────────────────────────────────────
  // Signaling handlers
  // ──────────────────────────────────────────────────────────────────────────

  void _registerSignalingHandlers() {
    if (_handlersRegistered) return;
    _handlersRegistered = true;

    // ── DJ-side ──────────────────────────────────────────────────────────────

    // Listener is requesting the DJ to create an WebRTC offer
    _socket.on('webrtc_offer_requested', (data) async {
      final fromUserId = data['fromUserId']?.toString();
      if (fromUserId == null || !_isHost) return;
      debugPrint('🎙️ Offer requested by $fromUserId');
      await _createAndSendOffer(fromUserId);
    });

    // Received SDP answer from a listener
    _socket.on('webrtc_answer', (data) async {
      final fromUserId = data['fromUserId']?.toString();
      final sdpMap = data['sdp'];
      if (fromUserId == null || sdpMap == null) return;
      final pc = _pcs[fromUserId];
      if (pc == null) return;
      debugPrint('🎙️ Answer received from $fromUserId');
      await pc.setRemoteDescription(
        RTCSessionDescription(sdpMap['sdp'], sdpMap['type']),
      );
    });

    // ── Listener-side ────────────────────────────────────────────────────────

    // DJ is now streaming – request an offer from the DJ
    _socket.on('mic_started', (data) {
      final hId = data['hostUserId']?.toString();
      if (hId != null) _hostUserId = hId;
      if (!_isHost && _hostUserId != null) {
        if (_hasUsableConnection(_hostUserId!)) {
          debugPrint('🎙️ mic_started – existing WebRTC session reused');
          return;
        }
        debugPrint('🎙️ mic_started → requesting offer from $_hostUserId');
        _requestOffer(_hostUserId!);
      }
    });

    _socket.on('mic_stopped', (_) {
      if (!_isHost) {
        // Keep existing connection alive and wait for next unmute.
        debugPrint('🎙️ mic_stopped – keeping WebRTC session alive');
      }
    });

    // Received SDP offer from DJ
    _socket.on('webrtc_offer', (data) async {
      final fromUserId = data['fromUserId']?.toString();
      final sdpMap = data['sdp'];
      if (fromUserId == null || sdpMap == null) return;
      debugPrint('🎙️ Offer received from $fromUserId');
      await _handleOffer(fromUserId, sdpMap);
    });

    // ── Common ────────────────────────────────────────────────────────────────

    // ICE candidate from any peer
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
      } catch (e) {
        debugPrint('⚠️ addCandidate error: $e');
      }
    });

    // A peer disconnected – close that connection
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

  // ──────────────────────────────────────────────────────────────────────────
  // Internal helpers
  // ──────────────────────────────────────────────────────────────────────────

  void _requestOffer(String hostUserId) {
    _socket.emit('request_webrtc_offer', {'targetUserId': hostUserId});
  }

  Future<RTCPeerConnection> _buildPc(String peerId) async {
    final pc = await createPeerConnection(_iceConfig);

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

    pc.onIceConnectionState = (s) =>
        debugPrint('🎙️ ICE[$peerId]: $s');

    pc.onTrack = (event) {
      // Audio tracks auto-play through the WebRTC native engine on mobile.
      // For iOS/Android no manual renderer is needed for audio-only.
      debugPrint('🎙️ Remote audio track received from $peerId');
    };

    _pcs[peerId] = pc;
    return pc;
  }

  Future<void> _createAndSendOffer(String listenerId) async {
    try {
      if (_hasUsableConnection(listenerId)) {
        debugPrint('🎙️ Reusing active PC for $listenerId (no new offer)');
        return;
      }

      _closePc(listenerId);
      final pc = await _buildPc(listenerId);

      if (_localStream != null) {
        for (final t in _localStream!.getAudioTracks()) {
          await pc.addTrack(t, _localStream!);
        }
      }

      final offer = await pc.createOffer({
        'offerToReceiveAudio': 0,
        'offerToReceiveVideo': 0,
      });
      await pc.setLocalDescription(offer);

      _socket.emit('webrtc_offer', {
        'targetUserId': listenerId,
        'sdp': {'sdp': offer.sdp, 'type': offer.type},
      });
      debugPrint('🎙️ Offer sent to $listenerId');
    } catch (e) {
      debugPrint('❌ _createAndSendOffer error: $e');
    }
  }

  Future<void> _handleOffer(String peerId, Map sdpMap) async {
    try {
      _closePc(peerId);
      final pc = await _buildPc(peerId);
      await pc.setRemoteDescription(
        RTCSessionDescription(sdpMap['sdp'], sdpMap['type']),
      );

      final answer = await pc.createAnswer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });
      await pc.setLocalDescription(answer);

      _socket.emit('webrtc_answer', {
        'targetUserId': peerId,
        'sdp': {'sdp': answer.sdp, 'type': answer.type},
      });
      debugPrint('🎙️ Answer sent to $peerId');
    } catch (e) {
      debugPrint('❌ _handleOffer error: $e');
    }
  }

  void _closePc(String peerId) {
    _pcs.remove(peerId)?.close();
    debugPrint('🎙️ Closed PC with $peerId');
  }

  bool _hasUsableConnection(String peerId) {
    final pc = _pcs[peerId];
    if (pc == null) return false;
    return pc.iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        pc.iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateCompleted ||
        pc.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
  }
}
