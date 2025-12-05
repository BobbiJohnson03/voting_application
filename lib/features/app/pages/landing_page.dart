import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_network.dart';
import '../../../core/services/app_state_service.dart';
import '../../../core/services/device_fingerprint.dart';
import '../../admin/pages/admin_dashboard_page.dart';
import 'qr_scanner_page.dart';
import '../../voting/session_selection_page.dart';

/// Keys for persisting client session in localStorage/SharedPreferences
class _SessionKeys {
  static const meetingId = 'client_meeting_id';
  static const meetingPassId = 'client_meeting_pass_id';
  static const meetingTitle = 'client_meeting_title';
  static const serverUrl = 'client_server_url';
}

class LandingPage extends StatefulWidget {
  final ApiNetwork apiNetwork;

  const LandingPage({super.key, required this.apiNetwork});

  @override
  State<LandingPage> createState() => _LandingPageState();

  /// Save meeting session to localStorage for persistence across refreshes
  static Future<void> saveSession({
    required String meetingId,
    required String meetingPassId,
    required String meetingTitle,
    required String serverUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_SessionKeys.meetingId, meetingId);
      await prefs.setString(_SessionKeys.meetingPassId, meetingPassId);
      await prefs.setString(_SessionKeys.meetingTitle, meetingTitle);
      await prefs.setString(_SessionKeys.serverUrl, serverUrl);
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  /// Clear saved session (e.g., when leaving meeting)
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_SessionKeys.meetingId);
      await prefs.remove(_SessionKeys.meetingPassId);
      await prefs.remove(_SessionKeys.meetingTitle);
      await prefs.remove(_SessionKeys.serverUrl);
    } catch (e) {
      debugPrint('Error clearing session: $e');
    }
  }
}

class _LandingPageState extends State<LandingPage> {
  bool _isAutoJoining = false;
  bool _isCheckingSession = true;
  String? _autoJoinCode;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  /// Check if user already has a saved meeting session
  Future<void> _checkSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final meetingId = prefs.getString(_SessionKeys.meetingId);
      final meetingPassId = prefs.getString(_SessionKeys.meetingPassId);
      final meetingTitle = prefs.getString(_SessionKeys.meetingTitle);
      final serverUrl = prefs.getString(_SessionKeys.serverUrl);

      // If we have a saved session, try to restore it
      if (meetingId != null && meetingPassId != null && serverUrl != null) {
        // Set up API network with saved server URL
        final appState = AppStateService.instance;
        appState.setServerUrl(serverUrl);
        final apiNetwork = appState.apiNetwork ?? ApiNetwork(serverUrl);

        // Check if server is still reachable
        try {
          await apiNetwork.health().timeout(
            const Duration(seconds: 3),
          );
        } catch (e) {
          // Server not reachable - clear session and show landing page
          debugPrint('Server not reachable, clearing session: $e');
          await LandingPage.clearSession();
          if (mounted) {
            setState(() {
              _isCheckingSession = false;
            });
            _checkUrlForCode();
          }
          return;
        }

        // Navigate to session selection page
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SessionsSelectionPage(
                apiNetwork: apiNetwork,
                meetingId: meetingId,
                meetingPassId: meetingPassId,
                meetingTitle: meetingTitle ?? 'Meeting',
                initialSessions: const [],
                serverUrl: serverUrl, // Pass serverUrl to enable fetching!
              ),
            ),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Error checking saved session: $e');
    }

    // No saved session - check URL for code
    setState(() {
      _isCheckingSession = false;
    });
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

      final meetingTitle =
          joinResponse['meeting']?['title'] as String? ?? 'Meeting';

      // Save session for persistence across page refreshes
      await LandingPage.saveSession(
        meetingId: meetingId,
        meetingPassId: meetingPassId,
        meetingTitle: meetingTitle,
        serverUrl: serverUrl,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SessionsSelectionPage(
              apiNetwork: apiNetwork,
              meetingId: meetingId,
              meetingPassId: meetingPassId,
              meetingTitle: meetingTitle,
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
    // Show loading screen while checking saved session
    if (_isCheckingSession) {
      return Scaffold(
        appBar: AppBar(title: const Text('Secure Voting System')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

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
