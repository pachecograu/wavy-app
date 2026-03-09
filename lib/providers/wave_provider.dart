import 'package:flutter/foundation.dart';
import '../core/wave_service.dart';
import '../core/socket_service.dart';

class WaveProvider with ChangeNotifier {
  final WaveService _waveService = WaveService();
  final SocketService _socketService = SocketService();
  
  List<Wave> _waves = [];
  bool _isLoading = false;
  
  List<Wave> get waves => _waves;
  bool get isLoading => _isLoading;
  
  void initialize() {
    _socketService.connect();
    loadWaves();
  }
  
  Future<void> loadWaves() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _waves = await _waveService.getWaves();
    } catch (e) {
      print('Error loading waves: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  void joinWave(String waveId) {
    _socketService.joinWave(waveId);
  }
  
  void createWave(String name, String djName) {
    _socketService.createWave({
      'name': name,
      'creator': djName,
    });
  }
  
  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }
}