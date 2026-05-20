import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/incident_provider.dart';
import '../../models/agent_trace.dart';

class AgentTraceScreen extends StatefulWidget {
  final String incidentId;

  const AgentTraceScreen({super.key, required this.incidentId});

  @override
  State<AgentTraceScreen> createState() => _AgentTraceScreenState();
}

class _AgentTraceScreenState extends State<AgentTraceScreen> {
  List<AgentTrace> _traces = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrace();
  }

  void _loadTrace() async {
    final t = await context.read<IncidentProvider>().fetchAgentTrace(widget.incidentId);
    if (mounted) {
      setState(() {
        _traces = t;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Agent Trace'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71)))
          : _traces.isEmpty
              ? const Center(child: Text('No trace available for this incident.', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _traces.length,
                  itemBuilder: (context, index) {
                    final trace = _traces[index];
                    return _buildTraceCard(trace, index);
                  },
                ),
    );
  }

  Widget _buildTraceCard(AgentTrace trace, int index) {
    bool isError = trace.status.toLowerCase() == 'error';
    Color borderColor = isError ? const Color(0xFFE74C3C) : const Color(0xFF2ECC71);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor.withOpacity(0.5), width: 1),
      ),
      child: ExpansionTile(
        iconColor: Colors.white,
        collapsedIconColor: Colors.white54,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF0D1117),
              child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trace.agent, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(trace.timestamp.split('T').last.split('.').first, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                ],
              ),
            ),
            if (isError)
              const Icon(Icons.warning, color: Color(0xFFE74C3C)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            trace.outputSummary,
            style: TextStyle(color: isError ? const Color(0xFFE74C3C) : const Color(0xFF8B949E)),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        children: [
          if (trace.fullOutput != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black26,
              width: double.infinity,
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(trace.fullOutput),
                style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF2ECC71), fontSize: 12),
              ),
            )
        ],
      ),
    );
  }
}
