// lib/services/wifi_service.dart
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:wifi_iot/wifi_iot.dart';

class WifiService {
  /// Check if WiFi scanning is supported on the device
  Future<bool> get isScanningSupported async {
    return await WiFiScan.instance.canStartScan() == CanStartScan.yes;
  }

  /// Request necessary permissions for WiFi scanning
  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.location.request();
      return status.isGranted;
    }
    return true;
  }

  /// Scan for available WiFi networks
  Future<List<WiFiAccessPoint>> scanNetworks() async {
    final canScan = await requestPermissions();
    if (!canScan) {
      throw Exception('Location permission is required for WiFi scanning');
    }

    final canStartScan = await WiFiScan.instance.canStartScan();
    if (canStartScan != CanStartScan.yes) {
      throw Exception('Cannot start WiFi scan: $canStartScan');
    }

    try {
      return await WiFiScan.instance.getScannedResults();
    } catch (e) {
      throw Exception('Failed to scan networks: $e');
    }
  }

  /// Connect to a WiFi network
  Future<bool> connectToNetwork(String ssid, {String? password}) async {
    try {
      // First, disconnect from current network
      await WiFiForIoTPlugin.disconnect();

      // Determine security type
      NetworkSecurity security = NetworkSecurity.NONE;
      if (password != null && password.isNotEmpty) {
        security =
            NetworkSecurity.WPA; // Default to WPA if password is provided
      }

      // Connect to the network
      return await WiFiForIoTPlugin.connect(
        ssid,
        password: password,
        security: security,
        joinOnce: false,
      );
    } catch (e) {
      debugPrint('Error connecting to WiFi: $e');
      return false;
    }
  }

  /// Get current connected WiFi network
  Future<String?> getCurrentNetwork() async {
    try {
      return await WiFiForIoTPlugin.getSSID();
    } catch (e) {
      debugPrint('Error getting current network: $e');
      return null;
    }
  }
}
