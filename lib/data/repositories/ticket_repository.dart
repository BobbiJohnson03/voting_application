import 'package:hive/hive.dart';
import '../models/ticket.dart';
import '../_boxes.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:math';

class TicketRepository {
  Box<Ticket>? _box;
  Box<String>? _idxPassSessionToTicket;

  Future<Box<Ticket>> _open() async =>
      _box ??= await Hive.openBox<Ticket>(boxTicket);

  Future<Box<String>> _openIdx() async => _idxPassSessionToTicket ??=
      await Hive.openBox<String>('idx_ticket_byPassSession');

  String _composeKey(String meetingPassId, String sessionId) =>
      '$meetingPassId|$sessionId';

  Future<Ticket?> byMeetingPassAndSession(
    String meetingPassId,
    String sessionId,
  ) async {
    final idx = await _openIdx();
    final ticketId = idx.get(_composeKey(meetingPassId, sessionId));
    if (ticketId == null) return null;
    final box = await _open();
    return box.get(ticketId);
  }

  Future<Ticket> create({
    required String sessionId,
    required String meetingPassId,
    required String deviceFingerprint,
  }) async {
    // Input validation
    if (deviceFingerprint.isEmpty) {
      throw ArgumentError('Device fingerprint cannot be empty');
    }
    if (sessionId.isEmpty || meetingPassId.isEmpty) {
      throw ArgumentError('Session ID and Meeting Pass ID cannot be empty');
    }

    final box = await _open();
    final idx = await _openIdx();

    // Check if ticket already exists
    final existingKey = _composeKey(meetingPassId, sessionId);
    final existingId = idx.get(existingKey);
    if (existingId != null) {
      final existing = box.get(existingId);
      if (existing != null && existing.isValid) {
        return existing; // Return existing valid ticket
      }
    }

    // Create new ticket
    final ticket = Ticket(
      id: _generateId(meetingPassId, sessionId),
      sessionId: sessionId,
      issuedAt: DateTime.now(),
      isUsed: false,
      meetingPassId: meetingPassId,
      deviceFingerprint: deviceFingerprint,
    );

    await box.put(ticket.id, ticket);
    await idx.put(existingKey, ticket.id);
    return ticket;
  }

  String _generateId(String meetingPassId, String sessionId) {
    final data =
        '$meetingPassId$sessionId${DateTime.now().millisecondsSinceEpoch}${_randomString(8)}';
    return sha256.convert(utf8.encode(data)).toString().substring(0, 24);
  }

  Future<Ticket?> get(String ticketId) async {
    final box = await _open();
    return box.get(ticketId);
  }

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  Future<void> markAsUsed(String ticketId) async {
    final box = await _open();
    final ticket = box.get(ticketId);
    if (ticket != null && !ticket.isUsed) {
      ticket.isUsed = true;
      await ticket.save();
    }
  }

  // Fixed: More accurate forMeeting implementation
  Future<List<Ticket>> forMeetingPass(String meetingPassId) async {
    final box = await _open();
    return box.values
        .where((t) => t.meetingPassId == meetingPassId)
        .toList(growable: false);
  }

  // New: Get active tickets for a meeting pass
  Future<List<Ticket>> activeForMeetingPass(String meetingPassId) async {
    final box = await _open();
    return box.values
        .where((t) => t.meetingPassId == meetingPassId && t.isValid)
        .toList(growable: false);
  }

  Future<bool> isValid(String ticketId) async {
    final box = await _open();
    final ticket = box.get(ticketId);
    return ticket != null && ticket.isValid;
  }

  // New: Clean up expired tickets
  Future<void> cleanupExpired() async {
    final box = await _open();
    final expiredTickets = box.values.where((t) => t.isExpired).toList();
    for (final ticket in expiredTickets) {
      await box.delete(ticket.id);
    }
  }
}
