import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SteeringWheel extends StatefulWidget {
  final WebSocketChannel channel;
  const SteeringWheel({super.key, required this.channel});

  @override
  State<SteeringWheel> createState() => _SteeringWheelState();
}

class _SteeringWheelState extends State<SteeringWheel> {
  double _angle = 0.0; // sudut setir (radian)
  double _lastTouchAngle = 0.0;
  final double maxRad = 480 * math.pi / 180; // ±480° = 960 total

  void _onPanStart(DragStartDetails details, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pos = details.localPosition;
    _lastTouchAngle = math.atan2(pos.dy - center.dy, pos.dx - center.dx);
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pos = details.localPosition;
    final dx = pos.dx - center.dx;
    final dy = pos.dy - center.dy;

    final newTouchAngle = math.atan2(dy, dx);
    if (newTouchAngle.isNaN) return;

    double delta = newTouchAngle - _lastTouchAngle;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;

    setState(() {
      _angle += delta;
      _angle = _angle.clamp(-maxRad, maxRad);

      // normalisasi ke -1.0 .. 1.0
      final normalized = _angle / maxRad;
      widget.channel.sink.add(normalized.toStringAsFixed(3));
    });

    _lastTouchAngle = newTouchAngle;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          onPanStart: (d) => _onPanStart(d, size),
          onPanUpdate: (d) => _onPanUpdate(d, size),
          onPanEnd: (_) {
            // reset ke tengah saat lepas jari
            setState(() {
              _angle = 0.0;
              widget.channel.sink.add("0.0");
            });
          },
          child: Center(
            child: Transform.rotate(
              angle: _angle,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade300,
                  border: Border.all(width: 8, color: Colors.black),
                ),
                child: const Center(child: Text("Steering Wheel")),
              ),
            ),
          ),
        );
      },
    );
  }
}