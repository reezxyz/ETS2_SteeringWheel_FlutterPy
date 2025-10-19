import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketManager {
  final String url;
  WebSocketChannel? _channel;
  bool _isConnecting = false;

  final _reconnectDelay = const Duration(seconds: 2);

  WebSocketManager(this.url);

  WebSocketChannel? get channel => _channel;

  void connect() {
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      print("Connected to $url");

      _channel!.stream.listen(
        (event) {
          // handle incoming if needed
        },
        onDone: _scheduleReconnect,
        onError: (e) {
          print("WebSocket error: $e");
          _scheduleReconnect();
        },
      );
    } catch (e) {
      print("Connection failed: $e");
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _scheduleReconnect() {
    if (_isConnecting) return;
    print("Reconnecting in ${_reconnectDelay.inSeconds}s...");
    Future.delayed(_reconnectDelay, connect);
  }

  void send(String data) {
    try {
      _channel?.sink.add(data);
    } catch (e) {
      print("Send failed: $e");
    }
  }

  void dispose() {
    _channel?.sink.close();
  }
}