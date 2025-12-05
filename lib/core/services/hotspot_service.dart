import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

// Import wifi_iot - on web this will fail but the stub will be used instead
// On Android, this will resolve correctly
import 'package:wifi_iot/wifi_iot.dart';

class HotspotService {
  static const String _ssid = 'VotingApp';
  static const String _password = 'vote12345678';

  bool _isHotspotEnabled = false;
  String? _hotspotIp;

  bool get isHotspotEnabled => _isHotspotEnabled;
  String? get hotspotIp => _hotspotIp;

  /// Check if device supports hotspot
  Future<bool> isHotspotSupported() async {
    if (!Platform.isAndroid) return false;

    try {
      return await WiFiForIoTPlugin.isWiFiAPEnabled();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking hotspot support: $e');
      }
      return false;
    }
  }

  /// Request necessary permissions
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return false;

    // Only request permissions that are actually available
    final permissions = [
      Permission.locationWhenInUse,
      Permission.systemAlertWindow,
    ];

    for (final permission in permissions) {
      final status = await permission.request();
      if (!status.isGranted) {
        if (kDebugMode) {
          debugPrint('Permission denied: ${permission.toString()}');
        }
        return false;
      }
    }

    return true;
  }

  /// Enable hotspot
  Future<bool> enableHotspot() async {
    if (!Platform.isAndroid) {
      throw Exception('Hotspot is only supported on Android');
    }

    try {
      // Check if already enabled
      if (await WiFiForIoTPlugin.isWiFiAPEnabled()) {
        _isHotspotEnabled = true;
        await _getHotspotIp();
        return true;
      }

      // Request permissions first
      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        throw Exception('Required permissions not granted');
      }

      // Enable hotspot
      // Note: On Android 8+, setting custom SSID/password programmatically
      // is restricted. The system will use default hotspot configuration.
      final success = await WiFiForIoTPlugin.setWiFiAPEnabled(true);

      if (success) {
        _isHotspotEnabled = true;
        await _getHotspotIp();

        if (kDebugMode) {
          debugPrint('✅ Hotspot enabled: $_ssid');
          debugPrint('📱 Hotspot IP: $_hotspotIp');
        }

        return true;
      } else {
        throw Exception('Failed to enable hotspot');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error enabling hotspot: $e');
      }
      _isHotspotEnabled = false;
      _hotspotIp = null;
      rethrow;
    }
  }

  /// Disable hotspot
  Future<bool> disableHotspot() async {
    if (!Platform.isAndroid) return false;

    try {
      final success = await WiFiForIoTPlugin.setWiFiAPEnabled(false);

      if (success) {
        _isHotspotEnabled = false;
        _hotspotIp = null;

        if (kDebugMode) {
          debugPrint('✅ Hotspot disabled');
        }
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error disabling hotspot: $e');
      }
      return false;
    }
  }

  /// Get hotspot IP address
  Future<void> _getHotspotIp() async {
    try {
      // Get network interfaces
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      // Look for hotspot interface (usually wlan0 or similar)
      for (final interface in interfaces) {
        if (interface.name.contains('wlan') ||
            interface.name.contains('ap') ||
            interface.name.contains('hotspot')) {
          for (final addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              _hotspotIp = addr.address;
              return;
            }
          }
        }
      }

      // Fallback: use first non-loopback interface
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            _hotspotIp = addr.address;
            return;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting hotspot IP: $e');
      }
      _hotspotIp = null;
    }
  }

  /// Get hotspot status
  Future<Map<String, dynamic>> getHotspotStatus() async {
    final isEnabled = await WiFiForIoTPlugin.isWiFiAPEnabled();

    return {
      'enabled': isEnabled,
      'ssid': isEnabled ? _ssid : null,
      'password': isEnabled ? _password : null,
      'ip': isEnabled ? _hotspotIp : null,
    };
  }

  /// Get connected clients
  /// Note: This feature may not be available on all Android versions
  Future<List<Map<String, dynamic>>> getConnectedClients() async {
    if (!_isHotspotEnabled) return [];

    try {
      // getClientList requires 2 positional arguments: onlyReachables, reachableTimeout
      final List<APClient> clients = await WiFiForIoTPlugin.getClientList(
        false,
        300,
      );

      return clients
          .map(
            (client) => {
              'ip': client.ipAddr,
              'mac': client.hwAddr,
              'device': client.device,
            },
          )
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting connected clients: $e');
      }
      return [];
    }
  }

  /// Dispose service
  void dispose() {
    _isHotspotEnabled = false;
    _hotspotIp = null;
  }
}
