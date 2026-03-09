import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static const String serverUrl = 'http://10.0.2.2:3001';
  late IO.Socket socket;
  
  void connect() {
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket', 'polling'],
      'autoConnect': false,
    });
    
    socket.connect();
    
    socket.onConnect((_) {
      print('🌊 Connected to WAVY backend');
    });
    
    socket.onDisconnect((_) {
      print('❌ Disconnected from backend');
    });
  }
  
  void disconnect() {
    socket.disconnect();
  }
  
  void joinWave(String waveId) {
    socket.emit('join-wave', waveId);
  }
  
  void leaveWave(String waveId) {
    socket.emit('leave-wave', waveId);
  }
  
  void createWave(Map<String, dynamic> data) {
    socket.emit('create-wave', data);
  }
}