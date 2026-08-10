import 'package:flutter/material.dart';

class PillSlider extends StatelessWidget {
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;
  final VoidCallback onRelease;

  const PillSlider({
    super.key,
    required this.value,
    required this.color,
    required this.onChanged,
    required this.onRelease,
  });

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: -1,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 22,
          activeTrackColor: color,
          inactiveTrackColor: color.withOpacity(0.25),
          thumbColor: Colors.white,
          overlayShape: SliderComponentShape.noOverlay,
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 10,
          ),
        ),
        child: Slider(
          value: value,
          min: 0.0,
          max: 1.0,
          onChanged: onChanged,
          onChangeEnd: (_) => onRelease(),
        ),
      ),
    );
  }
}
