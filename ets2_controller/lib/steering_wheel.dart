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
  double _angle = 0.0;             // sudut setir (radian)
  double _lastTouchAngle = 0.0;    // sudut sentuhan sebelumnya
  final double maxRad = 480 * math.pi / 180; // ±480° = 960 total

  DateTime _lastSend = DateTime.fromMillisecondsSinceEpoch(0);

  void _sendSteer(double normalized) {
    final now = DateTime.now();
    // throttle ~30 fps
    if (now.difference(_lastSend).inMilliseconds > 33) {
      widget.channel.sink.add("steer:${normalized.toStringAsFixed(3)}");
      _lastSend = now;
    }
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

    // Jika tepat di pusat, abaikan untuk hindari NaN
    if (dx == 0 && dy == 0) return;

    final newTouchAngle = math.atan2(dy, dx);
    if (newTouchAngle.isNaN) return;

    double delta = newTouchAngle - _lastTouchAngle;

    // Normalisasi delta ke -π..π agar tidak lompat
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;

    setState(() {
      _angle += delta;
      _angle = _angle.clamp(-maxRad, maxRad);

      // Normalisasi ke -1.0 .. 1.0 untuk dikirim ke server
      final normalized = _angle / maxRad;
      _sendSteer(normalized);
    });

    _lastTouchAngle = newTouchAngle;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Pastikan area persegi untuk wheel
        final side = math.min(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          onPanStart: (d) => _onPanStart(d, Size(side, side)),
          onPanUpdate: (d) => _onPanUpdate(d, Size(side, side)),
          onPanEnd: (_) {
            // Opsional: reset ke tengah saat lepas jari
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
                  color: Colors.grey.shade300,
                  border: Border.all(width: 8, color: Colors.black),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                  ],
                ),
                child: const Center(
                  child: Text(
                    "Steering Wheel",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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