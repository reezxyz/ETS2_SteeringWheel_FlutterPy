import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SignalControls extends StatelessWidget {
  final WebSocketChannel channel;
  const SignalControls({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () {
            channel.sink.add("signal:left");
          },
          child: const Icon(Icons.arrow_left),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () {
            channel.sink.add("signal:right");
          },
          child: const Icon(Icons.arrow_right),
        ),
      ],
    );
  }
}