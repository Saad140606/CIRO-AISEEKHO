import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import 'log_type_badge.dart';

class AgentStepTile extends StatelessWidget {
  final LogEntry log;
  final int index;

  const AgentStepTile({super.key, required this.log, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF0D1117),
              radius: 16,
              child: Text('${index + 1}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          log.agentName,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        log.timestamp.split('T').last.split('.').first, // HH:mm:ss
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LogTypeBadge(logType: log.type),
                  const SizedBox(height: 8),
                  Text(
                    log.message,
                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 14),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
