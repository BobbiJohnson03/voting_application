import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/* Purpose: Prevent ticket sharing between devices. Each ticket is tied to the device that scanned the QR code. */

class DeviceFingerprint {
  static const String _storageKey = 'device_fingerprint_v1';
  static String? _cachedFingerprint;

  /// Generate or retrieve a stable device fingerprint.
  /// On Web: fingerprint is stored in localStorage and reused.
  /// On Mobile: fingerprint is based on device info (stable across app restarts).
  static Future<String> generate() async {
    // Return cached fingerprint if available
    if (_cachedFingerprint != null) {
      return _cachedFingerprint!;
    }

    // Try to load saved fingerprint from storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      if (saved != null && isValidFingerprint(saved)) {
        _cachedFingerprint = saved;
        return saved;
      }
    } catch (e) {
      // Storage not available, continue to generate new one
    }

    // Generate new fingerprint
    String fingerprint;
    try {
      final info = await DeviceInfoPlugin().deviceInfo;

      if (info is AndroidDeviceInfo) {
        // Android: use stable device identifiers
        fingerprint = '${info.id}-${info.model}-${info.brand}-${info.device}';
      } else if (info is IosDeviceInfo) {
        // iOS: use vendor identifier (stable per app installation)
        fingerprint = '${info.identifierForVendor}-${info.model}-${info.name}';
      } else if (info is WebBrowserInfo) {
        // Web: use browser info + random seed (saved to localStorage)
        final seed = DateTime.now().millisecondsSinceEpoch;
        fingerprint = 'web-${info.browserName}-${info.platform}-${info.userAgent?.hashCode}-$seed';
      } else {
        // Other platforms: generate unique ID
        fingerprint = 'device-${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      // Fallback if device info fails
      fingerprint = 'fallback-${DateTime.now().millisecondsSinceEpoch}';
    }

    // Hash the fingerprint
    final hash = sha256.convert(utf8.encode(fingerprint)).toString();

    // Save to storage for future use
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, hash);
    } catch (e) {
      // Storage save failed, fingerprint will be regenerated next time
    }

    _cachedFingerprint = hash;
    return hash;
  }

  /// Clear the stored fingerprint (useful for testing)
  static Future<void> clear() async {
    _cachedFingerprint = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      // Ignore storage errors
    }
  }

  /// Validate if fingerprint looks reasonable
  static bool isValidFingerprint(String fingerprint) {
    return fingerprint.length == 64 && // SHA-256 produces 64 char hex string
        RegExp(r'^[a-f0-9]+$').hasMatch(fingerprint);
  }
}
