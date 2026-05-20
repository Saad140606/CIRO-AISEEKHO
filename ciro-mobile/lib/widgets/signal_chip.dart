import 'package:flutter/material.dart';

class SignalChip extends StatelessWidget {
  final String label;

  const SignalChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    String displayLabel = label;
    if (label.toLowerCase().contains('social')) {
      displayLabel = '📱 $label';
    } else if (label.toLowerCase().contains('weather')) {
      displayLabel = '🌧️ $label';
    } else if (label.toLowerCase().contains('traffic')) {
      displayLabel = '🚦 $label';
    }

    return Chip(
      label: Text(
        displayLabel,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: const Color(0xFF161B22),
      side: const BorderSide(color: Color(0xFF8B949E)),
    );
  }
}
