import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/models/wave.dart';

class WaveProvider with ChangeNotifier {
  final SocketService _socketService = SocketService();
  
  Wave? _currentWave;
  List<Wave> _onlineWaves = [];
  bool _isOwner = false;
  String? _userId;
  bool _isStreaming = false;
  
  Wave? get currentWave => _currentWave;
  List<Wave> get onlineWaves => _onlineWaves;
  bool get isOwner => _isOwner;
  bool get isOnline => _currentWave?.isOnline ?? false;
  int get listenersCount => _currentWave?.listenersCount ?? 0;
  bool get isStreaming => _isStreaming;
  
  void initialize(String userId) {
    _userId = userId;
    _socketService.connect(userId);
    _setupSocketListeners();
    _loadOnlineWaves();
  }
  
  void _setupSocketListeners() {
    _socketService.on('wave-online', (data) {
      try {
        // Handle data conversion more safely
        Map<String, dynamic> waveData;
        if (data is Map<String, dynamic>) {
          waveData = data;
        } else {
          final jsonString = jsonEncode(data);
          waveData = jsonDecode(jsonString) as Map<String, dynamic>;
        }
        final wave = Wave.fromJson(waveData);
        
        if (wave.ownerId == _userId) {
          _currentWave = wave;
          _isOwner = true;
          notifyListeners();
          // Auto-start streaming for owner
          autoStartStreamingWhenReady();
        }
        
        // Add to online waves list if not already present
        if (!_onlineWaves.any((w) => w.id == wave.id)) {
          _onlineWaves = List<Wave>.from(_onlineWaves)..add(wave);
          notifyListeners();
        }
      } catch (e) {
        print('Error parsing wave-online data: $e');
      }
    });
    
    _socketService.on('wave-offline', (data) {
      try {
        Map<String, dynamic> dataMap;
        if (data is Map<String, dynamic>) {
          dataMap = data;
        } else {
          final jsonString = jsonEncode(data);
          dataMap = jsonDecode(jsonString) as Map<String, dynamic>;
        }
        final waveId = dataMap['waveId'];
        
        _onlineWaves = _onlineWaves.where((w) => w.id != waveId).toList();
        if (_currentWave?.id == waveId) {
          _currentWave = null;
          _isOwner = false;
        }
        notifyListeners();
      } catch (e) {
        print('Error parsing wave-offline data: $e');
      }
    });
    
    _socketService.on('online-waves', (data) {
      try {
        List wavesList;
        if (data is List) {
          wavesList = data;
        } else {
          final jsonString = jsonEncode(data);
          wavesList = jsonDecode(jsonString) as List;
        }
        
        _onlineWaves = wavesList
            .map((waveData) => Wave.fromJson(waveData as Map<String, dynamic>))
            .toList();
        notifyListeners();
      } catch (e) {
        print('Error parsing online-waves data: $e');
        _onlineWaves = <Wave>[];
        notifyListeners();
      }
    });
    
    _socketService.on('listeners-update', (data) {
      try {
        Map<String, dynamic> dataMap;
        if (data is Map<String, dynamic>) {
          dataMap = data;
        } else {
          final jsonString = jsonEncode(data);
          dataMap = jsonDecode(jsonString) as Map<String, dynamic>;
        }
        final waveId = dataMap['waveId'];
        final count = dataMap['count'] ?? 0;
        
        // Update current wave if it matches
        if (_currentWave?.id == waveId) {
          _currentWave = Wave(
            id: _currentWave!.id,
            name: _currentWave!.name,
            djName: _currentWave!.djName,
            ownerId: _currentWave!.ownerId,
            isOnline: _currentWave!.isOnline,
            listenersCount: count,
            createdAt: _currentWave!.createdAt,
          );
        }
        
        // Update in online waves list
        final index = _onlineWaves.indexWhere((w) => w.id == waveId);
        if (index != -1) {
          _onlineWaves = List<Wave>.from(_onlineWaves);
          _onlineWaves[index] = Wave(
            id: _onlineWaves[index].id,
            name: _onlineWaves[index].name,
            djName: _onlineWaves[index].djName,
            ownerId: _onlineWaves[index].ownerId,
            isOnline: _onlineWaves[index].isOnline,
            listenersCount: count,
            createdAt: _onlineWaves[index].createdAt,
          );
        }
        
        notifyListeners();
      } catch (e) {
        print('Error parsing listeners-update data: $e');
      }
    });
    
    _socketService.on('wave-updated', (data) {
      try {
        Map<String, dynamic> waveData;
        if (data is Map<String, dynamic>) {
          waveData = data;
        } else {
          final jsonString = jsonEncode(data);
          waveData = jsonDecode(jsonString) as Map<String, dynamic>;
        }
        final updatedWave = Wave.fromJson(waveData);
        
        if (_currentWave?.id == updatedWave.id) {
          _currentWave = updatedWave;
        }
        
        // Update in online waves list
        final index = _onlineWaves.indexWhere((w) => w.id == updatedWave.id);
        if (index != -1) {
          _onlineWaves = List<Wave>.from(_onlineWaves);
          _onlineWaves[index] = updatedWave;
        }
        
        notifyListeners();
      } catch (e) {
        print('Error parsing wave-updated data: $e');
      }
    });
    
    // WebRTC streaming events
    _socketService.on('stream-answer', (data) {
      // Handle stream answer from listeners
      // This would be processed by the streaming service
    });
    
    _socketService.on('broadcast-offer', (data) {
      // Handle broadcast offers for listeners
      // This would be processed by the streaming service
    });
    
    _socketService.on('ice-candidate', (data) {
      // Handle ICE candidates for WebRTC connection
      // This would be processed by the streaming service
    });
  }
  
  void _loadOnlineWaves() {
    _socketService.emit('get-online-waves', {'userRole': 'oyente'});
  }
  
  void createWave(String name, String djName) {
    _socketService.emit('create-wave', {
      'name': name,
      'djName': djName,
      'userId': _userId,
    });
    _socketService.emit('log-action', {
      'action': 'EMISOR_ROLE_SELECTED',
      'userId': _userId,
      'waveName': name,
      'djName': djName
    });
  }
  
  // Auto-start streaming when wave is created and ready
  Future<void> autoStartStreamingWhenReady() async {
    if (_currentWave != null && _isOwner && !_isStreaming) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_currentWave != null && _isOwner && !_isStreaming) {
        await startStreaming();
        print('📡 Auto-started streaming for wave ${_currentWave!.id}');
      }
    }
  }
  
  Future<void> joinWave(String waveId) async {
    try {
      _socketService.emit('join-wave', {
        'waveId': waveId,
        'userId': _userId,
      });
      
      final wave = _onlineWaves.firstWhere(
        (w) => w.id == waveId,
        orElse: () => throw StateError('Wave not found'),
      );
      _currentWave = wave;
      _isOwner = false;
    
      _socketService.emit('log-action', {
        'action': 'OYENTE_SELECTED_WAVE',
        'userId': _userId,
        'waveId': waveId,
        'waveName': wave.name,
        'djName': wave.djName
      });
      
      notifyListeners();
    } catch (e) {
      print('Error joining wave: $e');
      rethrow;
    }
  }
  
  void updateWave(String name, String djName) {
    if (_currentWave != null && _isOwner) {
      _socketService.emit('update-wave', {
        'waveId': _currentWave!.id,
        'name': name,
        'djName': djName,
      });
    }
  }
  
  Future<void> startStreaming() async {
    if (_currentWave != null && _isOwner && !_isStreaming) {
      _isStreaming = true;
      notifyListeners();
    }
  }
  
  Future<void> stopStreaming() async {
    if (_isStreaming) {
      _isStreaming = false;
      notifyListeners();
    }
  }
  
  Future<void> stopWave() async {
    if (_currentWave != null && _isOwner) {
      await stopStreaming();
      _socketService.emit('stop-wave', {
        'waveId': _currentWave!.id,
        'userId': _userId,
      });
      _currentWave = null;
      _isOwner = false;
      notifyListeners();
    }
  }
  
  Future<void> leaveWave() async {
    if (_currentWave != null) {
      _socketService.emit('leave-wave', {
        'waveId': _currentWave!.id,
        'userId': _userId,
      });
      _currentWave = null;
      _isOwner = false;
      _isStreaming = false;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }
}