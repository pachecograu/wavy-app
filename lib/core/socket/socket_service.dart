import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;
  String? _userId;

  bool get isConnected => _isConnected;
  String? get userId => _userId;

  void connect(String userId) {
    if (_isConnected && _userId == userId) return;
    _userId = userId;
    _socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setTimeout(10000)
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _isConnected = true;
      _socket!.emit('user-connected', {'userId': userId});
      debugPrint('🌊 Connected to WAVY backend');
    });

    _socket!.onDisconnect((reason) {
      _isConnected = false;
      debugPrint('❌ Disconnected: $reason');
    });

    _socket!.onReconnect((attempt) {
      _isConnected = true;
      _socket!.emit('user-connected', {'userId': userId});
      debugPrint('🔄 Reconnected (attempt $attempt)');
    });

    _socket!.onConnectError((error) {
      debugPrint('🚨 Connection error: $error');
    });
  }

  void emit(String event, dynamic data) {
    if (_socket != null && _isConnected) {
      _socket!.emit(event, data);
    } else {
      debugPrint('⚠️ Socket not connected, queuing $event');
      Future.delayed(const Duration(seconds: 1), () {
        if (_socket != null && _isConnected) {
          _socket!.emit(event, data);
        } else {
          debugPrint('❌ Socket still not connected, dropping $event');
        }
      });
    }
  }

  void on(String event, Function(dynamic) callback) {
    if (_socket != null) {
      _socket!.on(event, callback);
    } else {
      debugPrint('⚠️ Socket not initialized, deferring on($event)');
      Future.delayed(const Duration(seconds: 1), () {
        if (_socket != null) _socket!.on(event, callback);
      });
    }
  }

  void off(String event) {
    _socket?.off(event);
  }

  void disconnect() {
    _socket?.disconnect();
    _isConnected = false;
  }
}
