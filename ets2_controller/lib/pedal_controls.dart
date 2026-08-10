import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'widgets/pill_slider.dart'; // <-- IMPORT PILL SLIDER

class PedalControls extends StatefulWidget {
  final WebSocketChannel channel;
  const PedalControls({super.key, required this.channel});

  @override
  State<PedalControls> createState() => _PedalControlsState();
}

class _PedalControlsState extends State<PedalControls> {
  double _gas = 0.0;
  double _brake = 0.0;

  void _send(String type, double value) {
    widget.channel.sink.add("$type:${value.toStringAsFixed(5)}");
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // =======================
        // BRAKE PEDAL
        // =======================
        Expanded(
          child: Column(
            children: [
              const Text(
                "Brake",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Expanded(
                child: PillSlider(
                  value: _brake,
                  color: Colors.redAccent,
                  onChanged: (val) {
                    setState(() => _brake = val);
                    _send("brake", val);
                  },
                  onRelease: () {
                    setState(() => _brake = 0.0);
                    _send("brake", 0.0);
                  },
                ),
              ),
              Text(
                "${(_brake * 100).round()}%",
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // =======================
        // GAS PEDAL
        // =======================
        Expanded(
          child: Column(
            children: [
              const Text(
                "Gas",
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Expanded(
                child: PillSlider(
                  value: _gas,
                  color: Colors.greenAccent,
                  onChanged: (val) {
                    setState(() => _gas = val);
                    _send("gas", val);
                  },
                  onRelease: () {
                    setState(() => _gas = 0.0);
                    _send("gas", 0.0);
                  },
                ),
              ),
              Text(
                "${(_gas * 100).round()}%",
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
