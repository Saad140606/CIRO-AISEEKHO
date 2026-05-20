import 'package:flutter/material.dart';
import '../models/incident.dart';

class CrisisSeverityBanner extends StatelessWidget {
  final Incident incident;

  const CrisisSeverityBanner({super.key, required this.incident});

  @override
  Widget build(BuildContext context) {
    Color severityColor;
    switch (incident.severity.toUpperCase()) {
      case 'HIGH':
      case 'CRITICAL':
        severityColor = const Color(0xFFE74C3C);
        break;
      case 'MEDIUM':
        severityColor = const Color(0xFFF39C12);
        break;
      default:
        severityColor = const Color(0xFF3498DB);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: severityColor.withOpacity(0.15),
        border: Border(left: BorderSide(color: severityColor, width: 6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ID: ${incident.id.split('-').first}',
                style: const TextStyle(fontFamily: 'monospace', color: Colors.white70),
              ),
              Chip(
                label: Text(
                  incident.status.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                backgroundColor: incident.status == 'processing'
                    ? Colors.orange.withOpacity(0.2)
                    : const Color(0xFF2ECC71).withOpacity(0.2),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            incident.crisisType.replaceAll('_', ' ').toUpperCase(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on, color: severityColor, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  incident.affectedArea, 
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.warning_amber, color: severityColor, size: 16),
              const SizedBox(width: 4),
              Text(incident.severity, style: TextStyle(color: severityColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Confidence:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: double.tryParse(incident.confidence.replaceAll('%', '')) != null
                      ? (double.parse(incident.confidence.replaceAll('%', '')) / 100)
                      : 0.5,
                  backgroundColor: Colors.white12,
                  color: severityColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(incident.confidence, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }
}
