import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/socket/socket_service.dart';
class QualityReport {
  final String userId;
  final int bitrate;
  final int latencyMs;
  final String bufferHealth;

  QualityReport({
    required this.userId,
    required this.bitrate,
    required this.latencyMs,
    required this.bufferHealth,
  });
}

class QualitySummary {
  final int listeners;
  final int avgBitrate;
  final int avgLatency;
  final int poorConnections;
  final List<QualityReport> reports;

  QualitySummary({
    required this.listeners,
    required this.avgBitrate,
    required this.avgLatency,
    required this.poorConnections,
    required this.reports,
  });
}

class QualityProvider with ChangeNotifier {
  final SocketService _socket = SocketService();

  String? _waveId;
  String? _userId;
  bool _isOwner = false;
  Timer? _reportTimer;

  // Oyente: local quality metrics
  int _localBitrate = 0;
  int _localLatency = 0;
  String _localBufferHealth = 'good';
  int _packetsReceived = 0;
  DateTime? _lastPacketTime;

  // Emisor: summary from all listeners
  QualitySummary? _summary;
  final Map<String, QualityReport> _listenerReports = {};

  int get localBitrate => _localBitrate;
  int get localLatency => _localLatency;
  String get localBufferHealth => _localBufferHealth;
  QualitySummary? get summary => _summary;
  Map<String, QualityReport> get listenerReports => _listenerReports;

  void initialize(String waveId, String userId, {required bool isOwner}) {
    _waveId = waveId;
    _userId = userId;
    _isOwner = isOwner;
    _setupListeners();

    if (isOwner) {
      // Emisor: poll summary every 5s
      _reportTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _socket.emit('get-quality-summary', {'waveId': _waveId});
      });
    } else {
      // Oyente: report quality every 3s (like AudiShare's monitorBitrate interval)
      _reportTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _measureAndReport();
      });
    }
  }

  void _setupListeners() {
    if (_isOwner) {
      // Emisor receives per-listener quality in real-time
      _socket.on('listener-quality', (data) {
        try {
          final d = _toMap(data);
          final uid = d['userId']?.toString() ?? '';
          _listenerReports[uid] = QualityReport(
            userId: uid,
            bitrate: (d['bitrate'] as num?)?.toInt() ?? 0,
            latencyMs: (d['latencyMs'] as num?)?.toInt() ?? 0,
            bufferHealth: d['bufferHealth']?.toString() ?? 'unknown',
          );
          notifyListeners();
        } catch (e) {
          debugPrint('Error parsing listener-quality: $e');
        }
      });

      // Emisor receives aggregated summary
      _socket.on('quality-summary', (data) {
        try {
          final d = _toMap(data);
          final reportsList = (d['reports'] as List?) ?? [];
          _summary = QualitySummary(
            listeners: (d['listeners'] as num?)?.toInt() ?? 0,
            avgBitrate: (d['avgBitrate'] as num?)?.toInt() ?? 0,
            avgLatency: (d['avgLatency'] as num?)?.toInt() ?? 0,
            poorConnections: (d['poorConnections'] as num?)?.toInt() ?? 0,
            reports: reportsList.map((r) {
              final rm = r is Map<String, dynamic> ? r : Map<String, dynamic>.from(r);
              return QualityReport(
                userId: rm['userId']?.toString() ?? '',
                bitrate: (rm['bitrate'] as num?)?.toInt() ?? 0,
                latencyMs: (rm['latencyMs'] as num?)?.toInt() ?? 0,
                bufferHealth: rm['bufferHealth']?.toString() ?? 'unknown',
              );
            }).toList(),
          );
          notifyListeners();
        } catch (e) {
          debugPrint('Error parsing quality-summary: $e');
        }
      });
    }

    // Both roles: track incoming audio packets for bitrate calculation
    _socket.on('receive-live-audio', (_) => _onPacketReceived());
    _socket.on('audio-data', (_) => _onPacketReceived());
    _socket.on('receive-audio-chunk', (_) => _onPacketReceived());
  }

  void _onPacketReceived() {
    final now = DateTime.now();
    if (_lastPacketTime != null) {
      _localLatency = now.difference(_lastPacketTime!).inMilliseconds;
    }
    _lastPacketTime = now;
    _packetsReceived++;
  }

  void _measureAndReport() {
    if (_waveId == null || _userId == null || _isOwner) return;

    // Estimate bitrate from packet count (rough: ~1KB per packet, 3s window)
    _localBitrate = (_packetsReceived * 8); // kbits in 3s window
    _localBufferHealth = _localLatency > 500
        ? 'poor'
        : _localLatency > 200
            ? 'fair'
            : 'good';

    _socket.emit('report-quality', {
      'waveId': _waveId,
      'userId': _userId,
      'bitrate': _localBitrate,
      'latencyMs': _localLatency,
      'bufferHealth': _localBufferHealth,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    _packetsReceived = 0;
    notifyListeners();
  }

  void clear() {
    _reportTimer?.cancel();
    _reportTimer = null;
    _waveId = null;
    _localBitrate = 0;
    _localLatency = 0;
    _localBufferHealth = 'good';
    _packetsReceived = 0;
    _lastPacketTime = null;
    _summary = null;
    _listenerReports.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _reportTimer?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(data)));
  }
}
