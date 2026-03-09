import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();
  
  late io.Socket _socket;
  bool _isConnected = false;
  
  bool get isConnected => _isConnected;
  
  void connect(String userId) {
    _socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'userId': userId})
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1000)
          .setTimeout(10000)
          .build(),
    );
    
    _socket.connect();
    
    _socket.onConnect((_) {
      print('🌊 Connected to WAVY backend at ${AppConfig.socketUrl}');
      _isConnected = true;
      // Emit user-connected event immediately after connection
      _socket.emit('user-connected', {'userId': userId});
    });
    
    _socket.onDisconnect((reason) {
      print('❌ Disconnected from WAVY backend: $reason');
      _isConnected = false;
    });
    
    _socket.onConnectError((error) {
      print('🚨 Connection error: $error');
    });
    
    _socket.onReconnect((attempt) {
      print('🔄 Reconnected to WAVY backend (attempt $attempt)');
      _isConnected = true;
      _socket.emit('user-connected', {'userId': userId});
    });
    
    _socket.onReconnectError((error) {
      print('❌ Reconnection error: $error');
    });
  }
  
  void emit(String event, dynamic data) {
    if (_isConnected) {
      _socket.emit(event, data);
    } else {
      print('⚠️ Socket not connected, cannot emit $event');
    }
  }
  
  void on(String event, Function(dynamic) callback) {
    _socket.on(event, callback);
  }
  
  void disconnect() {
    _socket.disconnect();
    _isConnected = false;
  }
}