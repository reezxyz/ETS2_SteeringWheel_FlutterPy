import 'package:flutter/material.dart';
import 'websocket_manager.dart';
import 'controller_page.dart';

void main() {
  final wsManager = WebSocketManager("ws://192.168.2.199:8765"); // ganti IP sesuai PC
  wsManager.connect();

  runApp(MyApp(wsManager: wsManager));
}

class MyApp extends StatelessWidget {
  final WebSocketManager wsManager;
  const MyApp({super.key, required this.wsManager});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ETS2 Controller',
      theme: ThemeData.dark(),
      home: ControllerPage(channel: wsManager.channel!),
    );
  }
}