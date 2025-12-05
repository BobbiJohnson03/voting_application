import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/network/api_network.dart';
import '../../../core/services/app_state_service.dart';
import '../../../core/services/device_fingerprint.dart';
import '../../voting/session_selection_page.dart';

class QrScannerPage extends StatefulWidget {
  final ApiNetwork apiNetwork;

  const QrScannerPage({super.key, required this.apiNetwork});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  MobileScannerController? _scannerController;
  bool _isScanning = true;
  bool _isProcessing = false;

  // Web manual input controllers
  final _joinCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// Get server URL from current browser location (for web)
  String _getServerUrlFromBrowser() {
    if (kIsWeb) {
      try {
        final uri = Uri.base;
        return '${uri.scheme}://${uri.host}:${uri.port}';
      } catch (e) {
        return 'http://localhost:8080';
      }
    }
    return 'http://localhost:8080';
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _scannerController = MobileScannerController();
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing || !_isScanning) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    if (barcode.rawValue == null) return;

    setState(() {
      _isProcessing = true;
      _isScanning = false;
    });

    try {
      // Parse QR code data
      if (barcode.rawValue!.startsWith('https://voteapp.local/') ||
          barcode.rawValue!.startsWith('voteapp://')) {
        // Parse custom URL scheme: voteapp://join?meetingId=xxx&serverUrl=xxx&joinCode=xxx
        // or HTTPS fallback: https://voteapp.local/join?meetingId=xxx&serverUrl=xxx&joinCode=xxx
        final uri = Uri.parse(barcode.rawValue!);
        if ((uri.scheme == 'voteapp' && uri.host == 'join') ||
            (uri.scheme == 'https' &&
                uri.host == 'voteapp.local' &&
                uri.path == '/join')) {
          final meetingId = uri.queryParameters['meetingId'];
          final serverUrl = uri.queryParameters['serverUrl'];
          final joinCode = uri.queryParameters['joinCode'];

          if (meetingId != null && serverUrl != null && joinCode != null) {
            await _handleJoinMeeting(meetingId, serverUrl, joinCode);
            return;
          }
        }
        throw Exception('Invalid QR code URL format');
      } else {
        // Handle legacy JSON format for backward compatibility
        final qrData = jsonDecode(barcode.rawValue!);
        final meetingId = qrData['meetingId'] as String?;
        final serverUrl = qrData['serverUrl'] as String?;
        final joinCode = qrData['joinCode'] as String?;

        if (meetingId == null || serverUrl == null || joinCode == null) {
          throw Exception('Invalid QR code format');
        }

        await _handleJoinMeeting(meetingId, serverUrl, joinCode);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isScanning = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning QR code: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleJoinMeeting(
    String meetingId,
    String serverUrl,
    String joinCode,
  ) async {
    final appState = AppStateService.instance;
    appState.setServerUrl(serverUrl);
    final apiNetwork = appState.apiNetwork ?? ApiNetwork(serverUrl);

    // Get device fingerprint
    final deviceFingerprint = await DeviceFingerprint.generate();

    // Join meeting
    final joinResponse = await apiNetwork.joinMeeting(
      meetingId: meetingId,
      deviceFingerprint: deviceFingerprint,
    );

    final meetingPassId = joinResponse['meetingPassId'] as String?;
    if (meetingPassId == null) {
      throw Exception('Failed to get meeting pass');
    }

    // Get active sessions from join response
    final activeSessions =
        (joinResponse['activeSessions'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    // Stop scanner
    await _scannerController?.stop();

    // Navigate to sessions selection
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SessionsSelectionPage(
            apiNetwork: apiNetwork,
            meetingId: meetingId,
            meetingPassId: meetingPassId,
            meetingTitle:
                joinResponse['meeting']?['title'] as String? ?? 'Meeting',
            initialSessions: activeSessions,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // On web, show manual entry form instead of camera scanner
    if (kIsWeb) {
      return _buildWebManualEntry();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
            onPressed: () {
              setState(() {
                _isScanning = !_isScanning;
              });
              if (_isScanning) {
                _scannerController?.start();
              } else {
                _scannerController?.stop();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Scanner
          if (_scannerController != null)
            MobileScanner(
              controller: _scannerController!,
              onDetect: _handleBarcode,
            ),

          // Overlay
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(40),
          ),

          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: const Text(
                'Position the QR code within the frame',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Processing...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build web-friendly manual entry form - only join code required
  Widget _buildWebManualEntry() {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Meeting')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon
                  const Icon(Icons.how_to_vote, size: 80, color: Colors.blue),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Enter Join Code',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ask the meeting organizer for the code',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Join Code field - prominent and large
                  TextFormField(
                    controller: _joinCodeController,
                    decoration: InputDecoration(
                      labelText: 'Join Code',
                      hintText: 'e.g. ABC123',
                      prefixIcon: const Icon(Icons.vpn_key, size: 28),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the join code';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Join button
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _handleWebJoin,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.login),
                    label: Text(_isProcessing ? 'Joining...' : 'Join Meeting'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(fontSize: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Handle web manual join
  Future<void> _handleWebJoin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Server URL is automatically detected from browser location
      final serverUrl = _getServerUrlFromBrowser();
      final joinCode = _joinCodeController.text.trim().toUpperCase();

      final appState = AppStateService.instance;
      appState.setServerUrl(serverUrl);
      final apiNetwork = appState.apiNetwork ?? ApiNetwork(serverUrl);

      // Get device fingerprint
      final deviceFingerprint = await DeviceFingerprint.generate();

      // First, get meeting by join code
      final joinResponse = await apiNetwork.joinMeetingByCode(
        joinCode: joinCode,
        deviceFingerprint: deviceFingerprint,
      );

      final meetingId = joinResponse['meetingId'] as String?;
      final meetingPassId = joinResponse['meetingPassId'] as String?;

      if (meetingId == null || meetingPassId == null) {
        throw Exception('Invalid response from server');
      }

      final activeSessions =
          (joinResponse['activeSessions'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SessionsSelectionPage(
              apiNetwork: apiNetwork,
              meetingId: meetingId,
              meetingPassId: meetingPassId,
              meetingTitle:
                  joinResponse['meeting']?['title'] as String? ?? 'Meeting',
              initialSessions: activeSessions,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
