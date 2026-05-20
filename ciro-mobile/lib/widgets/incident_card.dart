import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/incident.dart';

class IncidentCard extends StatelessWidget {
  final Incident incident;
  final VoidCallback onTap;

  const IncidentCard({super.key, required this.incident, required this.onTap});

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

    String formattedTime = incident.createdAt;
    try {
      final dt = DateTime.parse(incident.createdAt).toLocal();
      formattedTime = DateFormat('MMM d, HH:mm').format(dt);
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: severityColor, width: 6)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.crisisType.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: severityColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            incident.severity.toUpperCase(),
                            style: TextStyle(color: severityColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          incident.confidence,
                          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      incident.affectedArea,
                      style: const TextStyle(color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: [
                        Text(
                          'ID: ${incident.id.split('-').first}',
                          style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF8B949E), fontSize: 12),
                        ),
                        Text(
                          formattedTime,
                          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Chip(
                      label: Text(
                        incident.status.toUpperCase(),
                        style: const TextStyle(fontSize: 10),
                      ),
                      backgroundColor: incident.status == 'processing'
                          ? Colors.orange.withOpacity(0.2)
                          : const Color(0xFF2ECC71).withOpacity(0.2),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Icon(Icons.arrow_forward_ios, color: Color(0xFF8B949E), size: 16),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
