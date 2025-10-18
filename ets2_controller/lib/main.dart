import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'controller_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kunci ke landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Ganti IP ini dengan IP PC tempat server Python berjalan
    final channel = WebSocketChannel.connect(
      Uri.parse("ws://192.168.2.195:8765"),
    );

    return MaterialApp(
      title: 'ETS2 Controller',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: ControllerPage(channel: channel),
    );
  }
}