import 'dart:async';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class BroadcastManager {
  final Map<String, Set<WebSocketChannel>> _clients = {};

  FutureOr<Response> handleWs(Request req) {
    final mid = req.requestedUri.queryParameters['mid'] ?? 'default';
    _clients.putIfAbsent(mid, () => <WebSocketChannel>{});

    return webSocketHandler((socket) {
      _clients[mid]!.add(socket);
      socket.stream.listen((_) {}, onDone: () => _clients[mid]!.remove(socket));
    })(req);
  }

  void send(String meetingId, Map<String, dynamic> msg) {
    final set = _clients[meetingId];
    if (set == null || set.isEmpty) return;
    final data = jsonEncode(msg);
    for (final c in set) {
      c.sink.add(data);
    }
  }
}
