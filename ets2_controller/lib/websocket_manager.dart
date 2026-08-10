import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketManager {
  final String url;

  WebSocketChannel? _channel;
  bool _isConnecting = false;

  final _reconnectDelay = const Duration(seconds: 2);

  WebSocketManager(this.url);

  WebSocketChannel? get channel => _channel;

  Future<void> connect() async {
    if (_isConnecting) return;

    _isConnecting = true;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(url),
      );

      // Tunggu sampai WebSocket benar-benar siap.
      await _channel!.ready;

      print("Connected to $url");
    } catch (e) {
      print("Connection failed: $e");
      _channel = null;
      rethrow;
    } finally {
      _isConnecting = false;
    }

    _listen();
  }

  void _listen() {
    final channel = _channel;

    if (channel == null) return;

    channel.stream.listen(
      (event) {
        // Server tidak perlu mengirim data untuk kontrol sekarang.
      },
      onDone: () {
        print("WebSocket disconnected.");
      },
      onError: (e) {
        print("WebSocket error: $e");
      },
      cancelOnError: false,
    );
  }

  void send(String data) {
    try {
      _channel?.sink.add(data);
    } catch (e) {
      print("Send failed: $e");
    }
  }

  void dispose() {
    try {
      _channel?.sink.close();
    } catch (_) {}

    _channel = null;
  }
}
