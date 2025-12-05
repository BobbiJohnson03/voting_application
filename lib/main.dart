import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as pp;

// Models and adapters
import 'data/models/enums.dart';
import 'data/models/meeting.dart';
import 'data/models/option.dart';
import 'data/models/question.dart';
import 'data/models/voting.dart';
import 'data/models/signing_key.dart';
import 'data/models/ticket.dart';
import 'data/models/secure_vote.dart';
import 'data/models/result.dart';
import 'data/models/meeting_pass.dart';
import 'data/models/audit_log.dart';

// Services
import 'core/services/app_state_service.dart';
import 'core/network/api_network.dart';

// Pages
import 'features/app/pages/landing_page.dart';
import 'features/admin/pages/admin_dashboard_page.dart';
import 'features/admin/pages/session_results_page.dart';
import 'features/app/pages/qr_scanner_page.dart';
import 'features/voting/session_selection_page.dart';

Future<void> _initHive() async {
  if (kIsWeb) {
    await Hive.initFlutter();
  } else {
    final dir = await pp.getApplicationDocumentsDirectory();
    Hive.init(dir.path);
  }

  // ============ ENUMS ============
  Hive.registerAdapter(VotingTypeAdapter());
  Hive.registerAdapter(AnswersSchemaAdapter());
  Hive.registerAdapter(VotingStatusAdapter());
  Hive.registerAdapter(AuditActionAdapter());

  // ============ MODELS ============
  Hive.registerAdapter(MeetingAdapter());
  Hive.registerAdapter(OptionAdapter());
  Hive.registerAdapter(QuestionAdapter());
  Hive.registerAdapter(VotingAdapter());
  Hive.registerAdapter(SigningKeyAdapter());
  Hive.registerAdapter(TicketAdapter());
  Hive.registerAdapter(SecureVoteAdapter());
  Hive.registerAdapter(ResultAdapter());
  Hive.registerAdapter(MeetingPassAdapter());
  Hive.registerAdapter(AuditLogAdapter());

  debugPrint('Hive initialization complete - all adapters registered');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initHive();

  // Initialize device fingerprint
  final appState = AppStateService.instance;
  await appState.initializeDeviceFingerprint();

  // Default API network (will be updated when server URL is known)
  // For admin: server runs locally, URL will be set by ServerService
  // For client: server URL comes from QR code
  final defaultApiNetwork = ApiNetwork('http://localhost:8080');

  runApp(VotingApp(apiNetwork: defaultApiNetwork));
}

class VotingApp extends StatelessWidget {
  final ApiNetwork apiNetwork;

  const VotingApp({super.key, required this.apiNetwork});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'University Secure Voting',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: Routes.home,
      // Static routes (no arguments)
      routes: {
        Routes.home: (_) => LandingPage(apiNetwork: apiNetwork),
        Routes.adminHost: (_) => AdminPage(apiNetwork: apiNetwork),
        // ClientJoinPage removed - direct QR scan flow
        Routes.results: (_) => ResultsPage(apiNetwork: apiNetwork),
        Routes.qrScanner: (_) => QrScannerPage(apiNetwork: apiNetwork),
        // ❌ DO NOT put Routes.sessions here – it needs arguments
      },
      // Dynamic routes (with arguments)
      onGenerateRoute: (RouteSettings settings) {
        if (settings.name == Routes.sessions) {
          final args = settings.arguments as Map<String, dynamic>? ?? {};

          // Manual flow (from your .withManualData factory)
          if (args['isManual'] == true) {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => SessionsSelectionPage.withManualData(
                apiNetwork: apiNetwork,
                manualData: args,
              ),
            );
          }

          // Normal flow – expect meeting/session info in arguments
          final meetingId = args['meetingId'] as String?;
          final meetingPassId = args['meetingPassId'] as String?;
          final meetingTitle =
              (args['meetingTitle'] as String?) ?? 'Meeting sessions';
          final serverUrl = args['serverUrl'] as String?;

          final initialSessionsDynamic =
              args['initialSessions'] as List<dynamic>?;
          final initialSessions = initialSessionsDynamic != null
              ? initialSessionsDynamic
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList()
              : <Map<String, dynamic>>[];

          // Fail fast if required data is missing
          if (meetingId == null || meetingPassId == null) {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Navigation error')),
                body: const Center(
                  child: Text(
                    'Missing meetingId or meetingPassId in route arguments.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          final effectiveApi = serverUrl != null
              ? ApiNetwork(serverUrl)
              : apiNetwork;

          return MaterialPageRoute(
            settings: settings,
            builder: (_) => SessionsSelectionPage(
              apiNetwork: effectiveApi,
              meetingId: meetingId,
              meetingPassId: meetingPassId,
              meetingTitle: meetingTitle,
              initialSessions: initialSessions,
              serverUrl: serverUrl,
            ),
          );
        }

        // Let Flutter handle others or fall back to onUnknownRoute
        return null;
      },
      onUnknownRoute: (_) => MaterialPageRoute(
        builder: (_) => LandingPage(apiNetwork: apiNetwork),
      ),
    );
  }
}

class Routes {
  static const home = '/';
  static const adminHost = '/admin';
  static const results = '/results';
  static const qrScanner = '/qr';
  static const sessions = '/sessions';
}

// ============ APP STATE MANAGEMENT ============

/// Simple state management for the voting app
class AppState extends InheritedWidget {
  final ApiNetwork apiNetwork;
  final String? currentMeetingId;
  final String? currentSessionId;

  const AppState({
    super.key,
    required this.apiNetwork,
    required super.child,
    this.currentMeetingId,
    this.currentSessionId,
  });

  static AppState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppState>()!;
  }

  @override
  bool updateShouldNotify(AppState oldWidget) {
    return currentMeetingId != oldWidget.currentMeetingId ||
        currentSessionId != oldWidget.currentSessionId;
  }
}
