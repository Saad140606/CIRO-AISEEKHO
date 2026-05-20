import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/incident_provider.dart';
import '../widgets/sidebar.dart';
import 'main_tab/dashboard_screen.dart';
import 'main_tab/scenario_screen.dart';
import 'main_tab/signal_input_screen.dart';
import 'main_tab/map_screen.dart';
import 'main_tab/outcome_screen.dart';
import 'logs_tab/incidents_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidentProvider>().checkHealth();
      context.read<IncidentProvider>().fetchIncidents();
    });
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const ScenarioScreen();
      case 2:
        return const SignalInputScreen();
      case 3:
        return const IncidentsListScreen();
      case 4:
        return const CrisisMapScreen();
      case 5:
        return const OutcomeScreen();
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<IncidentProvider>().isSystemOnline;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('CIRO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          Center(
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isOnline ? 'System Online' : 'System Offline',
                  style: TextStyle(
                    color: isOnline ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 16),
              ],
            ),
          )
        ],
      ),
      body: Row(
        children: [
          Sidebar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.white12),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }
}
