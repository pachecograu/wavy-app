import 'package:flutter/foundation.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/services/device_id_service.dart';

class AuthProvider with ChangeNotifier {
  final SocketService _socketService = SocketService();
  String? _userId;
  String? _displayName;
  bool _isAuthenticated = false;
  
  String? get userId => _userId;
  String? get displayName => _displayName;
  bool get isAuthenticated => _isAuthenticated;
  
  Future<void> initialize() async {
    if (_userId == null) {
      _userId = await DeviceIdService.getDeviceId();
      _displayName = 'User ${_userId!.substring(_userId!.length - 4)}';
      _isAuthenticated = true;
      _socketService.connect(_userId!);
      notifyListeners();
    }
  }
  
  void loginAnonymous() async {
    if (_userId == null) {
      await initialize();
    }
    _socketService.emit('user-login', {
      'userId': _userId,
      'displayName': _displayName,
      'loginType': 'anonymous'
    });
  }
  
  void loginWithGoogle(String userId, String displayName) {
    _userId = userId;
    _displayName = displayName;
    _isAuthenticated = true;
    _socketService.connect(_userId!);
    _socketService.emit('user-login', {
      'userId': _userId,
      'displayName': _displayName,
      'loginType': 'google'
    });
    notifyListeners();
  }
  
  void logout() {
    if (_userId != null) {
      _socketService.emit('user-logout', {'userId': _userId});
    }
    _userId = null;
    _displayName = null;
    _isAuthenticated = false;
    _socketService.disconnect();
    notifyListeners();
  }
}