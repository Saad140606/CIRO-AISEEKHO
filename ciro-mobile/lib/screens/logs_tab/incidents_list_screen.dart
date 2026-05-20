import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/incident_provider.dart';
import '../../widgets/incident_card.dart';
import 'incident_detail_screen.dart';

class IncidentsListScreen extends StatelessWidget {
  const IncidentsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IncidentProvider>();
    final incidents = provider.incidents;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('All Incidents', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => provider.fetchIncidents(),
              )
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: provider.isLoading && incidents.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71)))
                : incidents.isEmpty
                    ? const Center(child: Text('No incidents recorded yet', style: TextStyle(color: Colors.white54)))
                    : RefreshIndicator(
                        color: const Color(0xFF2ECC71),
                        backgroundColor: const Color(0xFF161B22),
                        onRefresh: () => provider.fetchIncidents(),
                        child: ListView.builder(
                          itemCount: incidents.length,
                          itemBuilder: (context, index) {
                            return IncidentCard(
                              incident: incidents[index],
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => IncidentDetailScreen(incidentId: incidents[index].id),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
