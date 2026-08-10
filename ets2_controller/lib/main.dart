import 'package:flutter/material.dart';
import 'connect_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ETS2 Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const ConnectPage(),
    );
  }
}
