import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'steering_wheel.dart';

class ControllerPage extends StatefulWidget {
  final WebSocketChannel channel;
  const ControllerPage({super.key, required this.channel});

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage>
    with SingleTickerProviderStateMixin {
  double _gas = 0.0;   // 0.0 .. 1.0
  double _brake = 0.0; // 0.0 .. 1.0

  void _send(String type, double value) {
    widget.channel.sink.add("$type:${value.toStringAsFixed(3)}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // Steering wheel di kiri
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: SteeringWheel(channel: widget.channel),
              ),
            ),

            // Gas & Brake berdampingan horizontal di kanan
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Brake
                    Expanded(
                      child: Column(
                        children: [
                          const Text("Brake",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: -1,
                              child: Slider(
                                value: _brake,
                                min: 0.0,
                                max: 1.0,
                                onChanged: (val) {
                                  setState(() => _brake = val);
                                  _send("brake", val);
                                },
                                onChangeEnd: (_) {
                                  // saat jari dilepas, balik ke 0
                                  setState(() => _brake = 0.0);
                                  _send("brake", 0.0);
                                },
                              ),
                            ),
                          ),
                          Text("${(_brake * 100).round()}%"),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Gas
                    Expanded(
                      child: Column(
                        children: [
                          const Text("Gas",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: -1,
                              child: Slider(
                                value: _gas,
                                min: 0.0,
                                max: 1.0,
                                onChanged: (val) {
                                  setState(() => _gas = val);
                                  _send("gas", val);
                                },
                                onChangeEnd: (_) {
                                  // saat jari dilepas, balik ke 0
                                  setState(() => _gas = 0.0);
                                  _send("gas", 0.0);
                                },
                              ),
                            ),
                          ),
                          Text("${(_gas * 100).round()}%"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}