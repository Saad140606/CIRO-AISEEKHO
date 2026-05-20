import 'package:flutter/material.dart';

class LogTypeBadge extends StatelessWidget {
  final String logType;

  const LogTypeBadge({super.key, required this.logType});

  @override
  Widget build(BuildContext context) {
    final typeUpper = logType.toUpperCase();
    Color color;
    IconData icon;
    String label;

    switch (typeUpper) {
      case 'SIGNAL_INGESTION':
        color = Colors.blue;
        icon = Icons.cell_tower;
        label = 'INGEST';
        break;
      case 'EVENT_DETECTION':
        color = Colors.orange;
        icon = Icons.radar;
        label = 'DETECT';
        break;
      case 'SITUATION_ANALYSIS':
        color = Colors.purple;
        icon = Icons.psychology;
        label = 'ANALYZE';
        break;
      case 'ACTION_PLANNING':
        color = Colors.yellow.shade700;
        icon = Icons.checklist;
        label = 'PLAN';
        break;
      case 'SIMULATION_EXECUTION':
        color = const Color(0xFF2ECC71); // Green
        icon = Icons.play_circle_fill;
        label = 'EXECUTE';
        break;
      case 'OUTCOME_ASSESSMENT':
        color = Colors.teal;
        icon = Icons.bar_chart;
        label = 'ASSESS';
        break;
      case 'ERROR':
        color = const Color(0xFFE74C3C); // Red
        icon = Icons.warning;
        label = 'ERROR';
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
        label = typeUpper.isEmpty ? 'LOG' : typeUpper;
    }

    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 16),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color.withOpacity(0.3),
      side: BorderSide(color: color.withOpacity(0.5)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
