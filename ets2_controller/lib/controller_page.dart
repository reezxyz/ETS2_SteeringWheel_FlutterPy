import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'steering_wheel.dart';
import 'pedal_controls.dart';
import 'signal_controls.dart';
import 'camera_touchpad.dart';

class ControllerPage extends StatelessWidget {
  final WebSocketChannel channel;
  const ControllerPage({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Row(
          children: [
            // Steering wheel di kiri
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: SteeringWheel(channel: channel),
                  ),
                ),
              ),
            ),

            // Signal + Camera + Pedals di kanan
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    SignalControls(channel: channel),
                    const SizedBox(height: 24),

                    // Row agar CameraTouchpad di kiri, PedalControls di kanan
                    Expanded(
                      child: Row(
                        children: [
                          // Touchpad ambil 1 bagian
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: CameraTouchpad(channel: channel),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Pedals ambil 2 bagian
                          Expanded(
                            flex: 2,
                            child: PedalControls(channel: channel),
                          ),
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