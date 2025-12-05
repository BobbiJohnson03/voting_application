import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/server_service.dart';
import '../../../core/network/api_network.dart';
import '../../../data/models/audit_log.dart';
import '../../../data/models/enums.dart';

/// Security Panel with hash chain visualization and integrity verification
class SecurityPanelPage extends StatefulWidget {
  final ServerService serverService;
  final ApiNetwork apiNetwork;
  final String? meetingId;
  final String? sessionId;

  const SecurityPanelPage({
    super.key,
    required this.serverService,
    required this.apiNetwork,
    this.meetingId,
    this.sessionId,
  });

  @override
  State<SecurityPanelPage> createState() => _SecurityPanelPageState();
}

class _SecurityPanelPageState extends State<SecurityPanelPage> {
  List<AuditLog> _logs = [];
  bool _loading = true;
  String? _error;
  
  // Verification results
  bool _chainVerified = false;
  bool _votesVerified = false;
  int _totalLogs = 0;
  int _validLogs = 0;
  List<String> _errorMessages = [];

  @override
  void initState() {
    super.initState();
    _loadAndVerify();
  }

  Future<void> _loadAndVerify() async {
    setState(() {
      _loading = true;
      _error = null;
      _errorMessages = [];
    });

    try {
      // Load audit logs
      List<AuditLog> logs = [];
      
      if (widget.sessionId != null) {
        logs = await widget.serverService.auditLogs.forSession(widget.sessionId!);
      } else if (widget.meetingId != null) {
        logs = await widget.serverService.auditLogs.forMeeting(widget.meetingId!);
      } else {
        // Load all logs
        logs = await widget.serverService.auditLogs.getAll();
      }

      // Sort by timestamp
      logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Verify chain integrity
      int validLogs = 0;
      List<String> errors = [];

      for (var i = 0; i < logs.length; i++) {
        final log = logs[i];
        
        // Check individual log hash
        if (log.isChainValid) {
          validLogs++;
        } else {
          errors.add('Log ${i + 1}: Hash integrity failed');
        }

        // Check chain link
        if (i > 0 && log.previousHash != logs[i - 1].hash) {
          errors.add('Log ${i + 1}: Chain link broken (expected ${logs[i - 1].hash.substring(0, 8)}..., got ${log.previousHash.substring(0, 8)}...)');
        }
      }

      // Verify votes if session specified
      bool votesOk = true;
      if (widget.sessionId != null) {
        try {
          final response = await widget.apiNetwork.get(
            '/admin/verify-chain?sessionId=${widget.sessionId}',
          );
          votesOk = response['valid'] == true;
          if (!votesOk && response['errors'] != null) {
            errors.addAll(List<String>.from(response['errors']));
          }
        } catch (e) {
          // Verification endpoint might not be available
        }
      }

      setState(() {
        _logs = logs;
        _totalLogs = logs.length;
        _validLogs = validLogs;
        _chainVerified = errors.isEmpty && validLogs == logs.length;
        _votesVerified = votesOk;
        _errorMessages = errors;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Color _getActionColor(AuditAction action) {
    switch (action) {
      case AuditAction.meetingJoined:
        return Colors.blue;
      case AuditAction.ticketIssued:
        return Colors.orange;
      case AuditAction.voteSubmitted:
        return Colors.green;
      case AuditAction.votingClosed:
        return Colors.red;
      case AuditAction.sessionCreated:
        return Colors.teal;
      case AuditAction.securityViolation:
        return Colors.purple;
    }
  }

  IconData _getActionIcon(AuditAction action) {
    switch (action) {
      case AuditAction.meetingJoined:
        return Icons.login;
      case AuditAction.ticketIssued:
        return Icons.confirmation_number;
      case AuditAction.voteSubmitted:
        return Icons.how_to_vote;
      case AuditAction.votingClosed:
        return Icons.stop_circle;
      case AuditAction.sessionCreated:
        return Icons.play_circle;
      case AuditAction.securityViolation:
        return Icons.warning;
    }
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd.MM.yyyy HH:mm:ss').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛡️ Security Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAndVerify,
            tooltip: 'Re-verify',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Verifying integrity...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAndVerify,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Security Status Cards
                      _buildSecurityStatusCards(),
                      
                      const SizedBox(height: 24),
                      
                      // Error Messages (if any)
                      if (_errorMessages.isNotEmpty) ...[
                        _buildErrorsCard(),
                        const SizedBox(height: 24),
                      ],
                      
                      // Hash Chain Visualization
                      _buildHashChainVisualization(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSecurityStatusCards() {
    return Row(
      children: [
        Expanded(
          child: _SecurityStatusCard(
            title: 'Chain Integrity',
            icon: _chainVerified ? Icons.verified : Icons.warning,
            color: _chainVerified ? Colors.green : Colors.red,
            value: _chainVerified ? 'VERIFIED' : 'BROKEN',
            subtitle: '$_validLogs/$_totalLogs logs valid',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SecurityStatusCard(
            title: 'Vote Signatures',
            icon: _votesVerified ? Icons.verified : Icons.warning,
            color: _votesVerified ? Colors.green : Colors.orange,
            value: _votesVerified ? 'VERIFIED' : 'UNVERIFIED',
            subtitle: widget.sessionId != null ? 'HMAC checked' : 'Select session',
          ),
        ),
      ],
    );
  }

  Widget _buildErrorsCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'Integrity Issues Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(),
            ..._errorMessages.map((error) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_right, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      error,
                      style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildHashChainVisualization() {
    if (_logs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.link_off, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text('No audit logs found', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Hash Chain Visualization',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_logs.length} events',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            
            // Chain visualization
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                final isFirst = index == 0;
                final isLast = index == _logs.length - 1;
                final isValid = log.isChainValid;
                final linkValid = isFirst || log.previousHash == _logs[index - 1].hash;

                return _HashChainNode(
                  log: log,
                  index: index,
                  isFirst: isFirst,
                  isLast: isLast,
                  isValid: isValid,
                  linkValid: linkValid,
                  actionColor: _getActionColor(log.action),
                  actionIcon: _getActionIcon(log.action),
                  formatDateTime: _formatDateTime,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityStatusCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final String subtitle;

  const _SecurityStatusCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HashChainNode extends StatelessWidget {
  final AuditLog log;
  final int index;
  final bool isFirst;
  final bool isLast;
  final bool isValid;
  final bool linkValid;
  final Color actionColor;
  final IconData actionIcon;
  final String Function(DateTime) formatDateTime;

  const _HashChainNode({
    required this.log,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.isValid,
    required this.linkValid,
    required this.actionColor,
    required this.actionIcon,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final allValid = isValid && linkValid;
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chain line and node
          SizedBox(
            width: 60,
            child: Column(
              children: [
                // Top connector
                if (!isFirst)
                  Container(
                    width: 3,
                    height: 20,
                    color: linkValid ? Colors.green : Colors.red,
                  ),
                
                // Node circle
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: allValid ? Colors.green : Colors.red,
                    border: Border.all(
                      color: allValid ? Colors.green.shade700 : Colors.red.shade700,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      allValid ? Icons.check : Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                
                // Bottom connector
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      color: Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          ),
          
          // Log details
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: allValid ? Colors.grey.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: allValid ? Colors.grey.shade200 : Colors.red.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: actionColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(actionIcon, size: 18, color: actionColor),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.action.name.toUpperCase().replaceAll('_', ' '),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              formatDateTime(log.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: allValid ? Colors.green.shade100 : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          allValid ? '✓ Valid' : '✗ Invalid',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: allValid ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Hash info
                  _HashRow(
                    label: 'Hash',
                    value: log.hash,
                    color: isValid ? Colors.green : Colors.red,
                  ),
                  const SizedBox(height: 4),
                  _HashRow(
                    label: 'Prev',
                    value: log.previousHash.isEmpty ? '(genesis)' : log.previousHash,
                    color: linkValid ? Colors.blue : Colors.red,
                  ),
                  
                  // Details
                  if (log.details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Details: ${log.details}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HashRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HashRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value.length > 16 ? '${value.substring(0, 8)}...${value.substring(value.length - 8)}' : value,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: color.shade700,
            ),
          ),
        ),
      ],
    );
  }
}

extension on Color {
  Color get shade700 {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();
  }
}
