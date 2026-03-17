import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/socket/socket_service.dart';
class Message {
  final String id;
  final String userId;
  final String message;
  final String type;
  final DateTime timestamp;
  final String? toUserId;

  Message({
    required this.id,
    required this.userId,
    required this.message,
    required this.type,
    required this.timestamp,
    this.toUserId,
  });

  factory Message.fromJson(dynamic json) {
    try {
      // Convert to Map if it's a JS object
      Map<String, dynamic> data;
      if (json is Map<String, dynamic>) {
        data = json;
      } else {
        // Handle JS object by converting to Map
        data = Map<String, dynamic>.from(json);
      }
      
      return Message(
        id: data['id']?.toString() ?? '',
        userId: data['userId']?.toString() ?? data['fromUserId']?.toString() ?? '',
        message: data['message']?.toString() ?? '',
        type: data['type']?.toString() ?? 'public',
        timestamp: DateTime.tryParse(data['timestamp']?.toString() ?? '') ?? DateTime.now(),
        toUserId: data['toUserId']?.toString(),
      );
    } catch (e) {
      // Fallback for any parsing errors
      return Message(
        id: '',
        userId: '',
        message: 'Error loading message',
        type: 'public',
        timestamp: DateTime.now(),
        toUserId: null,
      );
    }
  }
}

class ChatProvider with ChangeNotifier {
  final SocketService _socketService = SocketService();
  
  List<Message> _publicMessages = [];
  List<Message> _privateMessages = [];
  String? _currentWaveId;
  String? _userId;
  
  List<Message> get publicMessages => _publicMessages;
  List<Message> get privateMessages => _privateMessages;
  
  bool _listenersRegistered = false;

  void initialize(String waveId, String userId) {
    if (_currentWaveId == waveId && _listenersRegistered) return;
    _currentWaveId = waveId;
    _userId = userId;
    if (!_listenersRegistered) {
      _listenersRegistered = true;
      _setupSocketListeners();
    }
  }
  
  void _setupSocketListeners() {
    _socketService.off('public-message');
    _socketService.off('private-message');
    _socketService.on('public-message', (data) {
      try {
        final jsonString = jsonEncode(data);
        final messageData = jsonDecode(jsonString) as Map<String, dynamic>;
        final message = Message.fromJson(messageData);
        _publicMessages = List<Message>.from(_publicMessages)..add(message);
        notifyListeners();
      } catch (e) {
        debugPrint('Error parsing public-message data: $e');
      }
    });
    
    _socketService.on('private-message', (data) {
      try {
        final jsonString = jsonEncode(data);
        final messageData = jsonDecode(jsonString) as Map<String, dynamic>;
        final message = Message.fromJson(messageData);
        _privateMessages = List<Message>.from(_privateMessages)..add(message);
        notifyListeners();
      } catch (e) {
        debugPrint('Error parsing private-message data: $e');
      }
    });
  }
  
  void sendPublicMessage(String message) {
    if (_currentWaveId != null && _userId != null) {
      _socketService.emit('send-public-message', {
        'waveId': _currentWaveId,
        'userId': _userId,
        'message': message,
      });
    }
  }
  
  void sendPrivateMessage(String toUserId, String message) {
    if (_currentWaveId != null && _userId != null) {
      _socketService.emit('send-private-message', {
        'waveId': _currentWaveId,
        'fromUserId': _userId,
        'toUserId': toUserId,
        'message': message,
      });
    }
  }
  
  void clearMessages() {
    _publicMessages.clear();
    _privateMessages.clear();
    notifyListeners();
  }
}