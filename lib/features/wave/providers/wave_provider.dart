import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/models/wave.dart';

enum EmisorState { connected, reconnecting, disconnected, offline, unknown }

class WaveProvider with ChangeNotifier {
  final SocketService _socketService = SocketService();

  Wave? _currentWave;
  List<Wave> _onlineWaves = [];
  bool _isOwner = false;
  String? _userId;
  bool _isStreaming = false;
  EmisorState _emisorState = EmisorState.unknown;

  Wave? get currentWave => _currentWave;
  List<Wave> get onlineWaves => _onlineWaves;
  bool get isOwner => _isOwner;
  bool get isOnline => _currentWave?.isOnline ?? false;
  int get listenersCount => _currentWave?.listenersCount ?? 0;
  bool get isStreaming => _isStreaming;
  EmisorState get emisorState => _emisorState;

  bool _initialized = false;

  void initialize(String userId) {
    _userId = userId;
    if (!_initialized) {
      _initialized = true;
      _setupSocketListeners();
    }
    // Always refresh waves list
    _onlineWaves = [];
    if (_socketService.isConnected) {
      _loadOnlineWaves();
    } else {
      Future.delayed(const Duration(seconds: 2), () {
        if (_socketService.isConnected) _loadOnlineWaves();
      });
    }
  }

  void _setupSocketListeners() {
    _socketService.on('wave-online', (data) {
      try {
        final wave = Wave.fromJson(_toMap(data));
        if (wave.ownerId == _userId) {
          _currentWave = wave;
          _isOwner = true;
          _emisorState = EmisorState.connected;
          notifyListeners();
          autoStartStreamingWhenReady();
        }
        if (!_onlineWaves.any((w) => w.id == wave.id)) {
          _onlineWaves = List<Wave>.from(_onlineWaves)..add(wave);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error parsing wave-online: $e');
      }
    });

    _socketService.on('wave-offline', (data) {
      try {
        final waveId = _toMap(data)['waveId'];
        _onlineWaves = _onlineWaves.where((w) => w.id != waveId).toList();
        if (_currentWave?.id == waveId) {
          _currentWave = null;
          _isOwner = false;
          _emisorState = EmisorState.offline;
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Error parsing wave-offline: $e');
      }
    });

    _socketService.on('online-waves', (data) {
      try {
        List wavesList = data is List ? data : jsonDecode(jsonEncode(data)) as List;
        _onlineWaves = wavesList.map((w) => Wave.fromJson(w as Map<String, dynamic>)).toList();
        notifyListeners();
      } catch (e) {
        debugPrint('Error parsing online-waves: $e');
        _onlineWaves = <Wave>[];
        notifyListeners();
      }
    });

    _socketService.on('listeners-update', (data) {
      try {
        final d = _toMap(data);
        final waveId = d['waveId'];
        final count = (d['count'] as num?)?.toInt() ?? 0;
        if (_currentWave?.id == waveId) {
          _currentWave = _currentWave!.copyWith(listenersCount: count);
        }
        final idx = _onlineWaves.indexWhere((w) => w.id == waveId);
        if (idx != -1) {
          _onlineWaves = List<Wave>.from(_onlineWaves);
          _onlineWaves[idx] = _onlineWaves[idx].copyWith(listenersCount: count);
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Error parsing listeners-update: $e');
      }
    });

    _socketService.on('wave-updated', (data) {
      try {
        final updatedWave = Wave.fromJson(_toMap(data));
        if (_currentWave?.id == updatedWave.id) _currentWave = updatedWave;
        final idx = _onlineWaves.indexWhere((w) => w.id == updatedWave.id);
        if (idx != -1) {
          _onlineWaves = List<Wave>.from(_onlineWaves);
          _onlineWaves[idx] = updatedWave;
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Error parsing wave-updated: $e');
      }
    });

    _socketService.on('emisor-state', (data) {
      try {
        final d = _toMap(data);
        final waveId = d['waveId'];
        final state = d['state']?.toString() ?? 'unknown';
        if (_currentWave?.id == waveId && !_isOwner) {
          _emisorState = _parseEmisorState(state);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error parsing emisor-state: $e');
      }
    });

    _socketService.on('emisor-reconnected', (data) {
      try {
        final d = _toMap(data);
        final waveId = d['waveId'];
        if (_currentWave?.id == waveId && !_isOwner) {
          _emisorState = EmisorState.connected;
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error parsing emisor-reconnected: $e');
      }
    });

    _socketService.on('error', (data) {
      debugPrint('❌ Backend error: $data');
    });
  }

  void _loadOnlineWaves() {
    _socketService.emit('get-online-waves', {'userRole': 'oyente'});
  }

  void refreshWaves() => _loadOnlineWaves();

  void createWave(String name, String djName, {String? genre, String? description}) {
    debugPrint('🌊 createWave called: name=$name, djName=$djName, userId=$_userId, socketConnected=${_socketService.isConnected}');
    _socketService.emit('create-wave', {
      'name': name,
      'djName': djName,
      'userId': _userId,
      'genre': genre ?? 'Sin información',
      'description': description ?? 'Sin información',
    });
  }

  Future<void> autoStartStreamingWhenReady() async {
    if (_currentWave != null && _isOwner && !_isStreaming) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_currentWave != null && _isOwner && !_isStreaming) {
        await startStreaming();
      }
    }
  }

  Future<void> joinWave(String waveId) async {
    try {
      _socketService.emit('join-wave', {'waveId': waveId, 'userId': _userId});
      final wave = _onlineWaves.firstWhere(
        (w) => w.id == waveId,
        orElse: () => throw StateError('Wave not found'),
      );
      _currentWave = wave;
      _isOwner = false;
      _socketService.emit('get-emisor-state', {'waveId': waveId});
      notifyListeners();
    } catch (e) {
      debugPrint('Error joining wave: $e');
      rethrow;
    }
  }

  void updateWave(String name, String djName, {String? genre, String? description}) {
    if (_currentWave != null && _isOwner) {
      _socketService.emit('update-wave', {
        'waveId': _currentWave!.id,
        'name': name,
        'djName': djName,
        'genre': genre,
        'description': description,
      });
      // Optimistic local update
      _currentWave = _currentWave!.copyWith(
        name: name,
        djName: djName,
        genre: genre ?? _currentWave!.genre,
        description: description ?? _currentWave!.description,
      );
      notifyListeners();
    }
  }

  /// Update a single field locally + emit to backend
  void updateField(String field, String value) {
    if (_currentWave == null || !_isOwner) return;
    switch (field) {
      case 'name':
        _currentWave = _currentWave!.copyWith(name: value);
        break;
      case 'djName':
        _currentWave = _currentWave!.copyWith(djName: value);
        break;
      case 'genre':
        _currentWave = _currentWave!.copyWith(genre: value);
        break;
      case 'description':
        _currentWave = _currentWave!.copyWith(description: value);
        break;
    }
    _socketService.emit('update-wave', {
      'waveId': _currentWave!.id,
      'name': _currentWave!.name,
      'djName': _currentWave!.djName,
      'genre': _currentWave!.genre,
      'description': _currentWave!.description,
    });
    notifyListeners();
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
      final waveId = _currentWave!.id;
      await stopStreaming();
      _socketService.emit('stop-wave', {'waveId': waveId, 'userId': _userId});
      _onlineWaves = _onlineWaves.where((w) => w.id != waveId).toList();
      _currentWave = null;
      _isOwner = false;
      _emisorState = EmisorState.offline;
      notifyListeners();
    }
  }

  Future<void> leaveWave() async {
    if (_currentWave != null) {
      _socketService.emit('leave-wave', {'waveId': _currentWave!.id, 'userId': _userId});
      _currentWave = null;
      _isOwner = false;
      _isStreaming = false;
      _emisorState = EmisorState.unknown;
      notifyListeners();
    }
  }

  EmisorState _parseEmisorState(String state) {
    switch (state) {
      case 'connected': return EmisorState.connected;
      case 'reconnecting': return EmisorState.reconnecting;
      case 'disconnected': return EmisorState.disconnected;
      case 'offline': return EmisorState.offline;
      default: return EmisorState.unknown;
    }
  }

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(data)));
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }
}
