import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:vote_app_thesis/network/api_network.dart';
import 'package:vote_app_thesis/services/app_state_service.dart';
import 'package:vote_app_thesis/services/device_fingerprint.dart';
import 'admin_page.dart';
import 'qr_scanner_page.dart';
import 'sessions_selection_page.dart';

class LandingPage extends StatefulWidget {
  final ApiNetwork apiNetwork;

  const LandingPage({super.key, required this.apiNetwork});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _isAutoJoining = false;
  String? _autoJoinCode;

  @override
  void initState() {
    super.initState();
    _checkUrlForCode();
  }

  /// Check if URL contains ?code=XXX parameter (from QR scan)
  void _checkUrlForCode() {
    if (!kIsWeb) return;

    try {
      final uri = Uri.base;
      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        setState(() {
          _autoJoinCode = code.toUpperCase();
        });
        // Auto-join after a short delay to let UI build
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _autoJoinWithCode(code.toUpperCase());
        });
      }
    } catch (e) {
      debugPrint('Error parsing URL: $e');
    }
  }

  /// Automatically join meeting with code from URL
  Future<void> _autoJoinWithCode(String joinCode) async {
    setState(() {
      _isAutoJoining = true;
    });

    try {
      // Get server URL from browser location
      final uri = Uri.base;
      final serverUrl = '${uri.scheme}://${uri.host}:${uri.port}';

      final appState = AppStateService.instance;
      appState.setServerUrl(serverUrl);
      final apiNetwork = appState.apiNetwork ?? ApiNetwork(serverUrl);

      // Get device fingerprint
      final deviceFingerprint = await DeviceFingerprint.generate();

      // Join meeting by code
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
        _isAutoJoining = false;
        _autoJoinCode = null;
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

  @override
  Widget build(BuildContext context) {
    // Show loading screen while auto-joining
    if (_isAutoJoining) {
      return Scaffold(
        appBar: AppBar(title: const Text('Secure Voting System')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Joining meeting...',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_autoJoinCode != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Code: $_autoJoinCode',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Secure Voting System')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'University Thesis Voting App',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminPage(apiNetwork: widget.apiNetwork),
                  ),
                );
              },
              child: const Text('Admin Mode'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        QrScannerPage(apiNetwork: widget.apiNetwork),
                  ),
                );
              },
              child: const Text('Join as Voter'),
            ),
          ],
        ),
      ),
    );
  }
}
