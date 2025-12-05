import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shelf/shelf.dart';
import 'package:mime/mime.dart';

/// Creates a handler that serves static files from Flutter assets.
/// This is used on Android/iOS where we can't access the filesystem directly,
/// but we can access bundled assets via rootBundle.
///
/// The web build files must be copied to assets/web/ before building the APK.
Handler createAssetStaticHandler() {
  return (Request request) async {
    var path = request.url.path;

    // Root path → serve index.html
    if (path.isEmpty || path == '/') {
      return _readWebAsset('assets/web/index.html');
    }

    // Remove leading slash if present
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    // Try to serve the requested file
    final assetPath = 'assets/web/$path';
    final assetResponse = await _readWebAsset(assetPath);

    // If file not found, return index.html for SPA routing
    if (assetResponse.statusCode == 404) {
      return _readWebAsset('assets/web/index.html');
    }

    return assetResponse;
  };
}

/// Read a web asset from the Flutter asset bundle
Future<Response> _readWebAsset(String assetPath) async {
  try {
    // Load asset from bundle
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();

    // Determine content type based on file extension
    final contentType = _getContentType(assetPath);

    return Response.ok(
      bytes,
      headers: {
        HttpHeaders.contentTypeHeader: contentType,
        // Disable caching to always get fresh content
        HttpHeaders.cacheControlHeader: 'no-cache, no-store, must-revalidate',
        HttpHeaders.pragmaHeader: 'no-cache',
        HttpHeaders.expiresHeader: '0',
      },
    );
  } catch (e) {
    // Asset not found
    return Response.notFound('File not found: $assetPath');
  }
}

/// Get MIME type for a file path
String _getContentType(String path) {
  final mimeType = lookupMimeType(path);

  if (mimeType != null) {
    return mimeType;
  }

  // Fallback for common web files
  if (path.endsWith('.html')) return 'text/html; charset=utf-8';
  if (path.endsWith('.js')) return 'application/javascript; charset=utf-8';
  if (path.endsWith('.css')) return 'text/css; charset=utf-8';
  if (path.endsWith('.json')) return 'application/json; charset=utf-8';
  if (path.endsWith('.png')) return 'image/png';
  if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
  if (path.endsWith('.svg')) return 'image/svg+xml';
  if (path.endsWith('.woff')) return 'font/woff';
  if (path.endsWith('.woff2')) return 'font/woff2';
  if (path.endsWith('.ttf')) return 'font/ttf';
  if (path.endsWith('.ico')) return 'image/x-icon';

  return 'application/octet-stream';
}

/// Check if we're running on a mobile platform where we need asset-based serving
bool get isMobilePlatform {
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (e) {
    return false;
  }
}
