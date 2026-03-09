import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

class SocketService {
  static SocketService? _instance;
  factory SocketService() {
    _instance ??= SocketService._internal();
    return _instance!;
  }
  SocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;
  String? _currentRoomId;
  String? _userId;

  Future<void> connect() async {
    if (_isConnected && _socket != null) return;

    try {
      print('🔌 Connecting to socket: ${AppConfig.socketUrl}');
      
      _socket = io.io(AppConfig.socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'timeout': 5000,
        'reconnection': false,
      });

      if (_socket == null) {
        throw Exception('Failed to create socket instance');
      }

      _socket!.on('connect', (_) {
        _isConnected = true;
        print('🔌 Socket connected successfully');
      });

      _socket!.on('disconnect', (reason) {
        _isConnected = false;
        print('❌ Socket disconnected: $reason');
      });

      _socket!.on('error', (data) {
        print('❌ Socket connection error: $data');
      });
      
      await Future.delayed(const Duration(milliseconds: 1000));
      
      if (!_socket!.connected) {
        _isConnected = false;
        print('⚠️ Socket not connected, continuing anyway');
      } else {
        _isConnected = true;
      }
    } catch (e) {
      print('❌ Error connecting socket: $e');
    }
  }

  Future<void> joinHybridRoom(String roomId, String userId, {bool isHost = false}) async {
    if (_isConnected && _socket != null && _currentRoomId == roomId) {
      print('⚠️ Already connected to room $roomId');
      return;
    }
    
    try {
      if (!_isConnected || _socket == null) {
        await connect();
      }
      
      if (_socket == null) {
        throw Exception('Socket failed to initialize');
      }
      
      _currentRoomId = roomId;
      _userId = userId;
      
      print('🌊 Emitting join_hybrid_room: roomId=$roomId, userId=$userId, isHost=$isHost');
      
      _socket!.emit('join_hybrid_room', {
        'roomId': roomId,
        'userId': userId,
        'isHost': isHost,
      });
      
      await Future.delayed(const Duration(milliseconds: 100));
      
    } catch (e) {
      print('❌ Error in joinHybridRoom: $e');
      _currentRoomId = null;
      rethrow;
    }
  }

  void requestVoiceToken() {
    if (_socket == null) {
      print('⚠️ Cannot request voice token: socket is null');
      return;
    }
    
    if (_currentRoomId != null) {
      print('🎙️ Emitting request_voice_token for room: $_currentRoomId');
      _socket!.emit('request_voice_token', {
        'roomId': _currentRoomId,
      });
    } else {
      print('⚠️ Cannot request voice token: no current room');
    }
  }

  void leaveHybridRoom() {
    if (_socket == null) {
      print('⚠️ Cannot leave room: socket is null');
      return;
    }
    
    print('🌊 Emitting leave_hybrid_room');
    _socket!.emit('leave_hybrid_room');
    _currentRoomId = null;
    _userId = null;
  }

  void getRoomStatus(String roomId) {
    if (_socket == null) return;
    _socket!.emit('get_room_status', {'roomId': roomId});
  }

  // Event listeners
  void onHybridRoomJoined(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      print('⚠️ Cannot set listener: socket is null');
      return;
    }
    _socket!.on('hybrid_room_joined', (data) {
      print('🌊 Received hybrid_room_joined: $data');
      if (data != null) {
        callback(Map<String, dynamic>.from(data));
      } else {
        print('⚠️ Received null data in hybrid_room_joined');
      }
    });
  }

  void onVoiceTokenGranted(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      print('⚠️ Cannot set listener: socket is null');
      return;
    }
    _socket!.on('voice_token_granted', (data) {
      print('🎙️ Received voice_token_granted: $data');
      if (data != null) {
        callback(Map<String, dynamic>.from(data));
      } else {
        print('⚠️ Received null data in voice_token_granted');
      }
    });
  }

  void onVoiceParticipantJoined(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      print('⚠️ Cannot set listener: socket is null');
      return;
    }
    _socket!.on('voice_participant_joined', (data) {
      print('🎙️ Received voice_participant_joined: $data');
      if (data != null) {
        callback(Map<String, dynamic>.from(data));
      } else {
        print('⚠️ Received null data in voice_participant_joined');
      }
    });
  }

  void onVoiceParticipantLeft(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      print('⚠️ Cannot set listener: socket is null');
      return;
    }
    _socket!.on('voice_participant_left', (data) {
      print('🎙️ Received voice_participant_left: $data');
      if (data != null) {
        callback(Map<String, dynamic>.from(data));
      } else {
        print('⚠️ Received null data in voice_participant_left');
      }
    });
  }

  void onRoomStatus(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      print('⚠️ Cannot set listener: socket is null');
      return;
    }
    _socket!.on('room_status', (data) {
      print('📊 Received room_status: $data');
      if (data != null) {
        callback(Map<String, dynamic>.from(data));
      } else {
        print('⚠️ Received null data in room_status');
      }
    });
  }

  void onError(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      print('⚠️ Cannot set listener: socket is null');
      return;
    }
    _socket!.on('error', (data) {
      print('❌ Received error: $data');
      if (data != null) {
        callback(Map<String, dynamic>.from(data));
      } else {
        print('⚠️ Received null data in error');
      }
    });
  }

  void onUserJoinedRoom(Function(Map<String, dynamic>) callback) {
    if (_socket == null) return;
    _socket!.on('user_joined_room', (data) {
      if (data != null) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }

  void onUserLeftRoom(Function(Map<String, dynamic>) callback) {
    if (_socket == null) return;
    _socket!.on('user_left_room', (data) {
      if (data != null) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }

  void onUserDisconnected(Function(Map<String, dynamic>) callback) {
    if (_socket == null) return;
    _socket!.on('user_disconnected', (data) {
      if (data != null) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }

  // Wave system events for real-time audio streaming
  void onReceiveLiveAudio(Function(Map<String, dynamic>) callback) {
    if (_socket == null) return;
    _socket!.on('receive-live-audio', (data) {
      try {
        if (data != null) {
          print('🎵 Received live audio buffer');
          callback(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        print('❌ Error in onReceiveLiveAudio: $e');
      }
    });
  }

  void onReceiveBits(Function(Map<String, dynamic>) callback) {
    if (_socket == null) return;
    _socket!.on('receive-bits', (data) {
      try {
        if (data != null) {
          print('📡 Received bits: ${data['byteSize']} bytes');
          callback(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        print('❌ Error in onReceiveBits: $e');
      }
    });
  }

  void onSongStarted(Function(Map<String, dynamic>) callback) {
    if (_socket == null) return;
    _socket!.on('song-started', (data) {
      try {
        if (data != null) {
          print('🎵 Song started: ${data['songData']}');
          callback(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        print('❌ Error in onSongStarted: $e');
      }
    });
  }

  void onSongControlUpdate(Function(Map<String, dynamic>) callback) {
    if (_socket == null) return;
    _socket!.on('song-control-update', (data) {
      try {
        if (data != null) {
          print('🎵 Song control: ${data['action']}');
          callback(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        print('❌ Error in onSongControlUpdate: $e');
      }
    });
  }

  void onAudioData(Function(Map<String, dynamic>) callback) {
    if (_socket == null) return;
    _socket!.on('audio-data', (data) {
      try {
        if (data != null) {
          callback(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        print('❌ Error in onAudioData: $e');
      }
    });
  }

  void onReceiveAudioChunk(Function(Map<String, dynamic>) callback) {
    if (_socket == null) return;
    _socket!.on('receive-audio-chunk', (data) {
      try {
        if (data != null) {
          callback(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        print('❌ Error in onReceiveAudioChunk: $e');
      }
    });
  }

  // Wave system methods
  void joinWave(String waveId, String userId) {
    emit('join-wave', {
      'waveId': waveId,
      'userId': userId,
    });
  }

  void leaveWave(String waveId, String userId) {
    emit('leave-wave', {
      'waveId': waveId,
      'userId': userId,
    });
  }

  void streamLiveAudio(String waveId, List<double> audioBuffer) {
    emit('live-audio', {
      'waveId': waveId,
      'audioBuffer': audioBuffer,
    });
  }

  void streamBits(String waveId, String bitsData, int byteSize) {
    emit('stream-bits', {
      'waveId': waveId,
      'bitsData': bitsData,
      'byteSize': byteSize,
    });
  }

  void startSong(String waveId, Map<String, dynamic> songData) {
    emit('start-song', {
      'waveId': waveId,
      'songData': songData,
    });
  }

  void controlSong(String waveId, String action, double currentTime) {
    emit('song-control', {
      'waveId': waveId,
      'action': action,
      'currentTime': currentTime,
    });
  }

  void streamAudio(String waveId, dynamic audioData) {
    emit('audio-stream', {
      'waveId': waveId,
      'audioData': audioData,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void streamAudioChunk(String waveId, dynamic chunk, int sequence) {
    emit('audio-chunk', {
      'waveId': waveId,
      'chunk': chunk,
      'sequence': sequence,
    });
  }

  void emit(String event, dynamic data) {
    if (_socket != null) {
      _socket!.emit(event, data);
      print('📤 Emitting $event: $data');
    } else {
      print('⚠️ Cannot emit $event: socket is null');
    }
  }

  Future<void> disconnect() async {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
      print('🔌 Socket disconnected');
    }
  }

  bool get isConnected => _isConnected;
  String? get currentRoomId => _currentRoomId;
  String? get userId => _userId;
}