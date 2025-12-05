import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Lightweight WebSocket client used by voter & admin UIs.
class WsService {
  final Uri wsUri;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  WsService(this.wsUri);

  void connect({
    void Function(dynamic msg)? onMessage,
    void Function()? onDone,
    void Function(Object err)? onError,
  }) {
    _channel = WebSocketChannel.connect(wsUri);
    _sub = _channel!.stream.listen(
      (msg) => onMessage?.call(msg),
      onDone: onDone,
      onError: onError,
      cancelOnError: true,
    );
  }

  void send(String data) => _channel?.sink.add(data);

  Future<void> close() async {
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _sub = null;
  }
}
