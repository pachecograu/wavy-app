import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/socket/socket_service.dart';
class VoiceProvider with ChangeNotifier {
  final SocketService _socket = SocketService();

  String? _waveId;
  String? _userId;
  bool _isOwner = false;

  // Locutor state (mic over music)
  bool _locutorActive = false;
  double _micVolume = 1.0;
  double _suggestedMusicVolume = 1.0;

  // Mic invitation state
  bool _micInvitePending = false;
  String? _micInviteFromUserId;

  bool get locutorActive => _locutorActive;
  double get micVolume => _micVolume;
  double get suggestedMusicVolume => _suggestedMusicVolume;
  bool get micInvitePending => _micInvitePending;
  String? get micInviteFromUserId => _micInviteFromUserId;

  bool _listenersRegistered = false;

  void initialize(String waveId, String userId, {required bool isOwner}) {
    _waveId = waveId;
    _userId = userId;
    _isOwner = isOwner;
    if (!_listenersRegistered) {
      _listenersRegistered = true;
      _setupListeners();
    }

    _socket.emit('get-mic-state', {'waveId': waveId});
  }

  void _setupListeners() {
    // Locutor events (received by oyentes)
    _socket.on('locutor-on', (data) {
      try {
        final d = _toMap(data);
        _locutorActive = true;
        _micVolume = (d['micVolume'] as num?)?.toDouble() ?? 1.0;
        _suggestedMusicVolume = (d['suggestedMusicVolume'] as num?)?.toDouble() ?? 0.3;
        notifyListeners();
      } catch (e) {
        debugPrint('Error parsing locutor-on: $e');
      }
    });

    _socket.on('locutor-off', (data) {
      _locutorActive = false;
      _suggestedMusicVolume = 1.0;
      notifyListeners();
    });

    _socket.on('locutor-balance-update', (data) {
      try {
        final d = _toMap(data);
        _micVolume = (d['micVolume'] as num?)?.toDouble() ?? 1.0;
        _suggestedMusicVolume = (d['suggestedMusicVolume'] as num?)?.toDouble() ?? 0.3;
        notifyListeners();
      } catch (e) {
        debugPrint('Error parsing locutor-balance-update: $e');
      }
    });

    _socket.on('mic-state', (data) {
      try {
        final d = _toMap(data);
        _locutorActive = d['isActive'] == true;
        _micVolume = (d['micVolume'] as num?)?.toDouble() ?? 0;
        _suggestedMusicVolume = (d['suggestedMusicVolume'] as num?)?.toDouble() ?? 1.0;
        notifyListeners();
      } catch (e) {
        debugPrint('Error parsing mic-state: $e');
      }
    });

    // Mic invitation events
    _socket.on('mic-invited', (data) {
      try {
        final d = _toMap(data);
        _micInvitePending = true;
        _micInviteFromUserId = d['fromUserId']?.toString();
        notifyListeners();
      } catch (e) {
        debugPrint('Error parsing mic-invited: $e');
      }
    });

    _socket.on('mic-accepted', (data) {
      notifyListeners();
    });

    _socket.on('mic-revoked', (data) {
      _micInvitePending = false;
      notifyListeners();
    });
  }

  // === Emisor actions ===

  void toggleLocutor() {
    if (!_isOwner || _waveId == null) return;

    if (_locutorActive) {
      _socket.emit('mic-over-music-off', {
        'waveId': _waveId,
        'userId': _userId,
      });
      _locutorActive = false;
      _suggestedMusicVolume = 1.0;
    } else {
      _socket.emit('mic-over-music-on', {
        'waveId': _waveId,
        'userId': _userId,
        'micVolume': _micVolume,
      });
      _locutorActive = true;
      _suggestedMusicVolume = 0.3;
    }
    notifyListeners();
  }

  void setLocutorBalance(double micVol, double musicVol) {
    if (!_isOwner || _waveId == null) return;
    _micVolume = micVol;
    _suggestedMusicVolume = musicVol;
    _socket.emit('locutor-balance', {
      'waveId': _waveId,
      'micVolume': micVol,
      'musicVolume': musicVol,
    });
    notifyListeners();
  }

  void inviteMic(String toUserId) {
    if (!_isOwner || _waveId == null) return;
    _socket.emit('invite-mic', {
      'waveId': _waveId,
      'fromUserId': _userId,
      'toUserId': toUserId,
    });
  }

  void revokeMic(String userId) {
    if (!_isOwner || _waveId == null) return;
    _socket.emit('revoke-mic', {
      'waveId': _waveId,
      'userId': userId,
    });
  }

  // === Oyente actions ===

  void acceptMicInvite() {
    if (_waveId == null) return;
    _micInvitePending = false;
    _socket.emit('accept-mic', {
      'waveId': _waveId,
      'userId': _userId,
    });
    notifyListeners();
  }

  void declineMicInvite() {
    _micInvitePending = false;
    notifyListeners();
  }

  void clear() {
    _waveId = null;
    _locutorActive = false;
    _micVolume = 1.0;
    _suggestedMusicVolume = 1.0;
    _micInvitePending = false;
    _micInviteFromUserId = null;
    notifyListeners();
  }

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(data)));
  }
}
