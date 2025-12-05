import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/* Purpose: Prevent ticket sharing between devices. Each ticket is tied to the device that scanned the QR code. */

class DeviceFingerprint {
  static Future<String> generate() async {
    try {
      final info = await DeviceInfoPlugin().deviceInfo;
      String fingerprint = '';

      if (info is AndroidDeviceInfo) {
        fingerprint = '${info.id}-${info.model}-${info.brand}-${info.device}';
      } else if (info is IosDeviceInfo) {
        fingerprint = '${info.identifierForVendor}-${info.model}-${info.name}';
      } else {
        // Fallback for web/other platforms
        fingerprint = '${DateTime.now().millisecondsSinceEpoch}-${info.data}';
      }

      // Add timestamp to make it more unique per installation
      fingerprint += '-${DateTime.now().millisecondsSinceEpoch}';

      return sha256.convert(utf8.encode(fingerprint)).toString();
    } catch (e) {
      // Fallback fingerprint if device info fails
      final fallback = 'fallback-${DateTime.now().millisecondsSinceEpoch}';
      return sha256.convert(utf8.encode(fallback)).toString();
    }
  }

  // Optional: Validate if fingerprint looks reasonable
  static bool isValidFingerprint(String fingerprint) {
    return fingerprint.length == 64 && // SHA-256 produces 64 char hex string
        RegExp(r'^[a-f0-9]+$').hasMatch(fingerprint);
  }
}
