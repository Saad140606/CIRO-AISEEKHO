import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/incident_provider.dart';
import '../../widgets/incident_card.dart';
import '../logs_tab/incident_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _launchSimulation(BuildContext context, String scenario) async {
    final provider = context.read<IncidentProvider>();
    final incidentId = await provider.simulateScenario(scenario);
    if (incidentId != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IncidentDetailScreen(incidentId: incidentId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IncidentProvider>();
    final incidents = provider.incidents;
    final activeCount = incidents.where((i) => i.status == 'processing').length;
    final lastCrisis = incidents.isNotEmpty ? incidents.first.crisisType.replaceAll('_', ' ').toUpperCase() : 'NONE';
    final isOnline = provider.isSystemOnline;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatCard('Active Incidents', activeCount.toString(), Icons.warning_amber, Colors.orange),
                const SizedBox(width: 16),
                _buildStatCard('Last Crisis', lastCrisis, Icons.history, Colors.blue),
                const SizedBox(width: 16),
                _buildStatCard('System Status', isOnline ? 'ONLINE' : 'OFFLINE', Icons.router, isOnline ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('Quick Simulate', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.0,
            children: [
              _buildScenarioButton(context, '🌊 Flooding G-10', 'flooding_g10'),
              _buildScenarioButton(context, '🌡️ Heatwave', 'heatwave_karachi'),
              _buildScenarioButton(context, '🚗 Accident', 'accident_mm_alam'),
              _buildScenarioButton(context, '⚡ Infra Failure', 'infra_failure_saddar'),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Recent Incidents', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          incidents.isEmpty && provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71)))
              : incidents.isEmpty
                  ? const Center(child: Text('No incidents recorded', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: incidents.length > 5 ? 5 : incidents.length,
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
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildScenarioButton(BuildContext context, String label, String value) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF2ECC71)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      onPressed: () => _launchSimulation(context, value),
      child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}
