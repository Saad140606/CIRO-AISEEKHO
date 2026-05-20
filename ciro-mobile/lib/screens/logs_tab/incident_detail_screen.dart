import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/incident_provider.dart';
import '../../widgets/crisis_severity_banner.dart';
import 'dart:convert';
import '../../models/agent_trace.dart';
import '../../models/incident.dart';
import 'package:shimmer/shimmer.dart';

class IncidentDetailScreen extends StatefulWidget {
  final String incidentId;

  const IncidentDetailScreen({super.key, required this.incidentId});

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  List<AgentTrace>? _traces;
  bool _isLoadingTrace = false;
  bool _traceLoadTriggered = false;
  Incident? _incident;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<IncidentProvider>();
      p.startStream(widget.incidentId);
      p.addListener(_onProviderChanged);
      _loadIncident();
    });
  }

  Future<void> _loadIncident() async {
    setState(() => _isLoading = true);
    try {
      final incident = await context.read<IncidentProvider>().fetchIncidentDetail(widget.incidentId);
      if (mounted) {
        if (incident?.id == widget.incidentId) {
          setState(() {
            _incident = incident;
            _isLoading = false;
            _hasError = false;
          });
          _tryLoadTrace();
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  void _onProviderChanged() {
    final p = context.read<IncidentProvider>();
    final incident = p.currentIncident;
    if (incident?.id == widget.incidentId) {
      setState(() => _incident = incident);
      _tryLoadTrace();
    }
  }

  void _tryLoadTrace() {
    final incident = _incident;
    final isComplete = incident != null && (incident.status == 'complete' || incident.status == 'error');
    if (isComplete && _traces == null && !_isLoadingTrace && !_traceLoadTriggered) {
      _traceLoadTriggered = true;
      context.read<IncidentProvider>().removeListener(_onProviderChanged);
      _loadTrace();
    }
  }

  void _loadTrace() async {
    if (_isLoadingTrace) return;
    setState(() => _isLoadingTrace = true);
    final t = await context.read<IncidentProvider>().fetchAgentTrace(widget.incidentId);
    if (mounted) {
      setState(() {
        _traces = t;
        _isLoadingTrace = false;
      });
    }
  }

  @override
  void dispose() {
    context.read<IncidentProvider>().removeListener(_onProviderChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incident = _incident;
    final isComplete = incident != null && (incident.status == 'complete' || incident.status == 'error');

    if (_isLoading || _hasError || incident == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        appBar: AppBar(backgroundColor: const Color(0xFF161B22), title: const Text('Analyzing...')),
        body: _buildShimmer(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Incident Detail'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CrisisSeverityBanner(incident: incident),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildImpactsCard(incident.impacts),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildActionsCard(incident.actions),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildSimulationCard(incident.simulations),
            ),
            const SizedBox(height: 16),
            if (incident.beforeState != null && incident.afterState != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildOutcomeCard(incident.beforeState!, incident.afterState!, incident.outcomeSummary ?? ''),
              ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Agent Trace', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 12),
            if (!isComplete && (_traces == null || _traces!.isEmpty))
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: Color(0xFF2ECC71)),
                      SizedBox(height: 16),
                      Text('Processing incident...', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              )
            else if (_isLoadingTrace)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71))),
              )
            else if (_traces == null || _traces!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('No trace available for this incident.', style: TextStyle(color: Colors.white54))),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: _traces!.asMap().entries.map((e) => _buildTraceCard(e.value, e.key)).toList(),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF161B22),
      highlightColor: const Color(0xFF2A313C),
      child: Column(
        children: [
          Container(height: 120, color: Colors.white),
          const SizedBox(height: 16),
          Container(height: 200, margin: const EdgeInsets.symmetric(horizontal: 16), color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildImpactsCard(List<String> impacts) {
    if (impacts.isEmpty) return const SizedBox();
    return Card(
      color: const Color(0xFF161B22),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Impact Assessment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            ...impacts.map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Color(0xFFE74C3C), fontWeight: FontWeight.bold)),
                  Expanded(child: Text(i, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ))
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(List<dynamic> actions) {
    if (actions.isEmpty) return const SizedBox();
    return Card(
      color: const Color(0xFF161B22),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recommended Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            ...actions.map((a) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline, color: Color(0xFF2ECC71)),
              title: Text(a.description, style: const TextStyle(color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis),
              subtitle: Text(a.target, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
              trailing: Chip(
                label: Text(a.type, style: const TextStyle(fontSize: 10)),
                backgroundColor: Colors.blue.withOpacity(0.2),
                side: BorderSide.none,
              ),
            ))
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationCard(List<dynamic> sims) {
    if (sims.isEmpty) return const SizedBox();
    return Card(
      color: const Color(0xFF161B22),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Simulated Execution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            ...sims.map((s) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                s.status == 'EXECUTED' ? Icons.play_circle_fill : Icons.error,
                color: s.status == 'EXECUTED' ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
              ),
              title: Text(s.outcome, style: const TextStyle(color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis),
              subtitle: Text(s.toolUsed, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
              trailing: Text(s.timestamp.toString().split('T').last.substring(0, 8), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ))
          ],
        ),
      ),
    );
  }

  Widget _buildOutcomeCard(Map<String, dynamic> before, Map<String, dynamic> after, String summary) {
    return Card(
      color: const Color(0xFF161B22),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Outcome Assessment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(summary, style: const TextStyle(color: Color(0xFF2ECC71), fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStateColumn('Before', before, const Color(0xFFE74C3C))),
                Container(width: 1, height: 100, color: Colors.white12),
                Expanded(child: _buildStateColumn('After', after, const Color(0xFF2ECC71))),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStateColumn(String title, Map<String, dynamic> state, Color titleColor) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...state.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text('${e.key.replaceAll('_', ' ')}: ${e.value}', style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
          ))
        ],
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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(trace.fullOutput),
                  style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF2ECC71), fontSize: 12),
                ),
              ),
            )
        ],
      ),
    );
  }
}
