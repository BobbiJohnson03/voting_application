import 'package:flutter/material.dart';
import '../../core/network/api_network.dart';

class ClientJoinPage extends StatelessWidget {
  final ApiNetwork apiNetwork;

  const ClientJoinPage({super.key, required this.apiNetwork});

  void _showManualEntryDialog(BuildContext context) {
    final serverUrlController = TextEditingController();
    final joinCodeController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Enter Meeting Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the server URL and join code provided by the meeting host.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: serverUrlController,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'http://192.168.43.1:8080',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: joinCodeController,
                decoration: const InputDecoration(
                  labelText: 'Join Code',
                  hintText: 'ABC123',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 10,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (serverUrlController.text.trim().isEmpty ||
                          joinCodeController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill all fields'),
                          ),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        // Create manual meeting data
                        final meetingData = {
                          'meetingId':
                              'manual-${DateTime.now().millisecondsSinceEpoch}',
                          'serverUrl': serverUrlController.text.trim(),
                          'joinCode': joinCodeController.text
                              .trim()
                              .toUpperCase(),
                          'isManual': true,
                        };

                        // Navigate to sessions selection with manual data
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          '/sessions',
                          arguments: meetingData,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        setState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Meeting'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              'Scan QR Code',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Scan the QR code provided by the meeting organizer',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/qr');
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _showManualEntryDialog(context),
              child: const Text('Enter Code Manually'),
            ),
          ],
        ),
      ),
    );
  }
}
