import 'dart:async';
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
  double _angle = 0.0;
  double _lastTouchAngle = 0.0;
  final double maxRad = 480 * math.pi / 180;

  Timer? _throttleTimer;

  void _sendSteer(double normalized) {
    if (_throttleTimer?.isActive ?? false) return;

    widget.channel.sink.add("steer:${normalized.toStringAsFixed(3)}");

    _throttleTimer = Timer(const Duration(milliseconds: 20), () {});
  }

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

    if (dx == 0 && dy == 0) return;
    final newTouchAngle = math.atan2(dy, dx);

    double delta = newTouchAngle - _lastTouchAngle;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;

    setState(() {
      _angle += delta;
      _angle = _angle.clamp(-maxRad, maxRad);
      final normalized = _angle / maxRad;
      _sendSteer(normalized);
    });

    _lastTouchAngle = newTouchAngle;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          onPanStart: (d) => _onPanStart(d, Size(side, side)),
          onPanUpdate: (d) => _onPanUpdate(d, Size(side, side)),
          onPanEnd: (_) {
            setState(() {
              _angle = 0.0;
              widget.channel.sink.add("steer:0.0");
            });
          },
          child: Center(
            child: Transform.rotate(
              angle: _angle,
              child: Container(
                width: side,
                height: side,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade400, width: 8),
                  gradient: RadialGradient(
                    colors: [Colors.black, Colors.grey.shade800],
                    center: Alignment.center,
                    radius: 0.9,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: side * 0.3,
                    height: side * 0.3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black87,
                      border: Border.all(color: Colors.grey.shade500, width: 3),
                    ),
                    child: const Center(
                      child: Icon(Icons.directions_car, color: Colors.white, size: 32),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}