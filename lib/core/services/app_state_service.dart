import 'dart:io';
import 'package:vote_app_thesis/services/device_fingerprint.dart';
import 'package:vote_app_thesis/network/api_network.dart';

/// Global app state service
/// Manages device fingerprint, server URL, and API network instance
class AppStateService {
  static AppStateService? _instance;
  static AppStateService get instance => _instance ??= AppStateService._();

  AppStateService._();

  String? _deviceFingerprint;
  String? _serverUrl;
  ApiNetwork? _apiNetwork;

  /// Initialize device fingerprint (call once at app startup)
  Future<String> initializeDeviceFingerprint() async {
    if (_deviceFingerprint == null) {
      _deviceFingerprint = await DeviceFingerprint.generate();
    }
    return _deviceFingerprint!;
  }

  /// Get device fingerprint
  String? get deviceFingerprint => _deviceFingerprint;

  /// Set server URL and update API network
  void setServerUrl(String serverUrl) {
    _serverUrl = serverUrl;
    _apiNetwork = ApiNetwork(serverUrl);
  }

  /// Get server URL
  String? get serverUrl => _serverUrl;

  /// Get API network instance
  ApiNetwork? get apiNetwork => _apiNetwork;

  /// Create API network with custom URL
  ApiNetwork createApiNetwork(String serverUrl) {
    return ApiNetwork(serverUrl);
  }

  /// Get local IP address for server hosting
  static Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      // Prefer 192.168.x.x addresses
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              addr.address.startsWith('192.168.')) {
            return addr.address;
          }
        }
      }

      // Fallback: first IPv4 address
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
