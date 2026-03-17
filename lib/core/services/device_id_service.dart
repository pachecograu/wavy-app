import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdService {
  static const String _deviceIdKey = 'wavy_device_id';
  static String? _cachedDeviceId;

  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    // Migrate old timestamp-based IDs to hardware ID
    if (deviceId != null && RegExp(r'wavy_android_\d+$').hasMatch(deviceId)) {
      deviceId = null;
      await prefs.remove(_deviceIdKey);
    }

    if (deviceId == null) {
      deviceId = await _getHardwareId();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    _cachedDeviceId = deviceId;
    return deviceId;
  }

  static Future<String> _getHardwareId() async {
    if (kIsWeb) return 'wavy_web_${DateTime.now().millisecondsSinceEpoch}';

    try {
      if (Platform.isAndroid) {
        // Android Settings.Secure.ANDROID_ID — unique per device+app
        const channel = MethodChannel('wavy/device');
        final id = await channel.invokeMethod<String>('getAndroidId');
        if (id != null && id.isNotEmpty) return 'wavy_$id';
      }
    } catch (e) {
      debugPrint('⚠️ Could not get hardware ID: $e');
    }

    // Fallback: generate once and persist
    final platform = Platform.operatingSystem;
    return 'wavy_${platform}_${DateTime.now().millisecondsSinceEpoch}';
  }
}