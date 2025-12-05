import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../services/server_service.dart';
import '../network/api_network.dart';
import '../models/meeting.dart';
import 'user_management_page.dart';
import 'sessions_list_page.dart';

class AdminPage extends StatefulWidget {
  final ApiNetwork apiNetwork;

  const AdminPage({Key? key, required this.apiNetwork}) : super(key: key);

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with WidgetsBindingObserver {
  final ServerService _serverService = ServerService();
  final Uuid _uuid = Uuid();

  bool _serverRunning = false;
  bool _serverStarting = false;
  String? _serverUrl;
  String? _serverError;

  // Meeting management
  Meeting? _activeMeeting;
  List<Meeting> _meetings = [];
  bool _loadingMeetings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkServerStatus();
    _loadMeetings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkServerStatus() async {
    setState(() {
      _serverStarting = true;
      _serverError = null;
    });

    try {
      final url = await _serverService.getServerUrl();
      setState(() {
        _serverRunning = true;
        _serverUrl = url;
      });
    } catch (e) {
      setState(() {
        _serverRunning = false;
        _serverError = e.toString();
      });
    } finally {
      setState(() {
        _serverStarting = false;
      });
    }
  }

  Future<void> _startServer() async {
    setState(() {
      _serverStarting = true;
      _serverError = null;
    });

    try {
      final url = await _serverService.startServer();
      setState(() {
        _serverRunning = true;
        _serverUrl = url;
      });
    } catch (e) {
      setState(() {
        _serverRunning = false;
        _serverError = e.toString();
      });
    } finally {
      setState(() {
        _serverStarting = false;
      });
    }
  }

  Future<void> _stopServer() async {
    setState(() {
      _serverStarting = true;
    });

    try {
      await _serverService.stopServer();
      setState(() {
        _serverRunning = false;
        _serverUrl = null;
      });
    } catch (e) {
      setState(() {
        _serverError = e.toString();
      });
    } finally {
      setState(() {
        _serverStarting = false;
      });
    }
  }

  // ============ MEETING MANAGEMENT ============

  Future<void> _loadMeetings() async {
    setState(() => _loadingMeetings = true);
    try {
      final meetings = await _serverService.meetings.getAll();
      setState(() {
        _meetings = meetings;
        // Set active meeting to the first active one
        _activeMeeting = meetings.where((m) => m.canJoin).firstOrNull;
        _loadingMeetings = false;
      });
    } catch (e) {
      setState(() => _loadingMeetings = false);
    }
  }

  Future<void> _createMeeting() async {
    final titleController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Meeting'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Meeting Title',
            hintText: 'Enter meeting name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != true || titleController.text.trim().isEmpty) return;

    try {
      final meeting = Meeting(
        id: _uuid.v4(),
        title: titleController.text.trim(),
        createdAt: DateTime.now(),
        isActive: true,
        joinCode: _generateJoinCode(),
      );

      await _serverService.meetings.put(meeting);
      await _loadMeetings();

      setState(() => _activeMeeting = meeting);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Meeting "${meeting.title}" created!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating meeting: $e')));
      }
    }
  }

  String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
      6,
      (i) => chars[(random + i * 7) % chars.length],
    ).join();
  }

  String _generateQrData() {
    if (_activeMeeting == null || _serverUrl == null) return '';

    // Generate QR as simple URL - works on all phones!
    // Format: http://192.168.x.x:8080?code=ABC123&t=timestamp
    // Timestamp prevents browser from using cached version
    final joinCode = _activeMeeting!.joinCode;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$_serverUrl?code=$joinCode&t=$timestamp';
  }

  void _navigateToSessions() {
    if (_activeMeeting == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create or select a meeting first'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionsListPage(
          meetingId: _activeMeeting!.id,
          serverService: _serverService,
          apiNetwork: widget.apiNetwork,
        ),
      ),
    ).then((_) => _loadMeetings());
  }

  void _showQrCode() {
    if (_serverUrl == null || _activeMeeting == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please start server and create a meeting first'),
        ),
      );
      return;
    }

    final qrData = _generateQrData();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan to Join Meeting'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: qrData, version: QrVersions.auto, size: 200.0),
            const SizedBox(height: 16),
            Text(
              _activeMeeting!.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Join Code: ${_activeMeeting!.joinCode}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            SelectableText(
              _serverUrl!,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          if (_serverUrl != null && _activeMeeting != null)
            IconButton(
              icon: const Icon(Icons.qr_code),
              onPressed: _showQrCode,
              tooltip: 'Show QR Code',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Server Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Server Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _serverRunning ? Icons.check_circle : Icons.error,
                          color: _serverRunning ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _serverRunning
                              ? 'Server is running'
                              : 'Server is not running',
                          style: TextStyle(
                            color: _serverRunning ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    if (_serverUrl != null) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _serverUrl!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('URL copied to clipboard'),
                            ),
                          );
                        },
                        child: Text(
                          'Server URL: $_serverUrl',
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                    if (_serverError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Error: $_serverError',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (!_serverRunning && !_serverStarting)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _startServer,
                          child: const Text('Start Server'),
                        ),
                      )
                    else if (_serverRunning)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _stopServer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Stop Server'),
                        ),
                      )
                    else
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Meeting Management Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Active Meeting',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _createMeeting,
                          tooltip: 'Create New Meeting',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingMeetings)
                      const Center(child: CircularProgressIndicator())
                    else if (_activeMeeting == null)
                      Column(
                        children: [
                          const Text(
                            'No active meeting',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _createMeeting,
                            icon: const Icon(Icons.add),
                            label: const Text('Create Meeting'),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.meeting_room,
                              color: Colors.green,
                            ),
                            title: Text(_activeMeeting!.title),
                            subtitle: Text(
                              'Join Code: ${_activeMeeting!.joinCode}',
                            ),
                            trailing: _meetings.length > 1
                                ? PopupMenuButton<Meeting>(
                                    onSelected: (meeting) {
                                      setState(() => _activeMeeting = meeting);
                                    },
                                    itemBuilder: (context) => _meetings
                                        .where((m) => m.canJoin)
                                        .map(
                                          (m) => PopupMenuItem(
                                            value: m,
                                            child: Text(m.title),
                                          ),
                                        )
                                        .toList(),
                                    child: const Icon(Icons.swap_horiz),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _navigateToSessions,
                              icon: const Icon(Icons.ballot),
                              label: const Text('Manage Sessions'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // QR Code Section
            if (_serverRunning && _serverUrl != null && _activeMeeting != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Join: ${_activeMeeting!.title}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Code: ${_activeMeeting!.joinCode}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: QrImageView(
                          data: _generateQrData(),
                          version: QrVersions.auto,
                          size: 200.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              final shareText =
                                  'Join voting meeting "${_activeMeeting!.title}"\n'
                                  'Server: $_serverUrl\n'
                                  'Join Code: ${_activeMeeting!.joinCode}';
                              Share.share(
                                shareText,
                                subject: 'Join Voting Meeting',
                              );
                            },
                            icon: const Icon(Icons.share),
                            label: const Text('Share'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: _generateQrData()),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('QR data copied to clipboard'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
