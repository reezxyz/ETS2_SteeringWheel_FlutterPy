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

class _ControllerPageState extends State<ControllerPage> {
  double _gas = 0.0;
  double _brake = 0.0;

  void _send(String type, double value) {
    widget.channel.sink.add("$type:${value.toStringAsFixed(3)}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // dark background
      body: SafeArea(
        child: Row(
          children: [
            // Steering wheel di kiri, lebih besar
            // Steering wheel di kiri, mentok kiri
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0), // jarak tipis dari tepi
                  child: AspectRatio(
                    aspectRatio: 1, // biar tetap bulat
                    child: SteeringWheel(channel: widget.channel),
                  ),
                ),
              ),
            ),
            // Gas & Brake di kanan
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Brake
                    Expanded(
                      child: Column(
                        children: [
                          const Text("Brake",
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: -1,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: Colors.redAccent,
                                  inactiveTrackColor: Colors.redAccent.withOpacity(0.3),
                                  thumbColor: Colors.redAccent,
                                  overlayColor: Colors.redAccent.withOpacity(0.2),
                                ),
                                child: Slider(
                                  value: _brake,
                                  min: 0.0,
                                  max: 1.0,
                                  onChanged: (val) {
                                    setState(() => _brake = val);
                                    _send("brake", val);
                                  },
                                  onChangeEnd: (_) {
                                    setState(() => _brake = 0.0);
                                    _send("brake", 0.0);
                                  },
                                ),
                              ),
                            ),
                          ),
                          Text("${(_brake * 100).round()}%",
                              style: const TextStyle(color: Colors.white70)),
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
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: -1,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: Colors.greenAccent,
                                  inactiveTrackColor: Colors.greenAccent.withOpacity(0.3),
                                  thumbColor: Colors.greenAccent,
                                  overlayColor: Colors.greenAccent.withOpacity(0.2),
                                ),
                                child: Slider(
                                  value: _gas,
                                  min: 0.0,
                                  max: 1.0,
                                  onChanged: (val) {
                                    setState(() => _gas = val);
                                    _send("gas", val);
                                  },
                                  onChangeEnd: (_) {
                                    setState(() => _gas = 0.0);
                                    _send("gas", 0.0);
                                  },
                                ),
                              ),
                            ),
                          ),
                          Text("${(_gas * 100).round()}%",
                              style: const TextStyle(color: Colors.white70)),
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