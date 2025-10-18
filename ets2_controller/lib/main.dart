import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'steering_wheel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ganti IP sesuai alamat server Python kamu
    final channel = WebSocketChannel.connect(
      Uri.parse("ws://192.168.2.195:8765"),
    );

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("ETS2 Controller")),
        body: SteeringWheel(channel: channel),
      ),
    );
  }
}