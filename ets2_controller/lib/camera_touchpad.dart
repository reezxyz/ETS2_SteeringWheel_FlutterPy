import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CameraTouchpad extends StatefulWidget {
  final WebSocketChannel channel;
  const CameraTouchpad({super.key, required this.channel});

  @override
  State<CameraTouchpad> createState() => _CameraTouchpadState();
}

class _CameraTouchpadState extends State<CameraTouchpad> {
  bool _active = false;
  Offset _lastPos = Offset.zero;

  void _sendDelta(Offset delta) {
    // Normalisasi delta agar tidak terlalu besar
    final dx = (delta.dx / 100).clamp(-1.0, 1.0);
    final dy = (delta.dy / 100).clamp(-1.0, 1.0);
    widget.channel.sink.add("camera:${dx.toStringAsFixed(3)},${dy.toStringAsFixed(3)}");
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        _active = true;
        _lastPos = details.globalPosition;
      },
      onPanUpdate: (details) {
        if (_active) {
          final delta = details.globalPosition - _lastPos;
          _lastPos = details.globalPosition;
          _sendDelta(delta);
        }
      },
      onPanEnd: (_) {
        _active = false;
        widget.channel.sink.add("camera:0.0,0.0"); // reset
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(0.2),
          border: Border.all(color: Colors.blueAccent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(Icons.open_with, color: Colors.white70),
        ),
      ),
    );
  }
}