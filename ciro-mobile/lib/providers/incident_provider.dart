import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api/ciro_api.dart';
import '../models/incident.dart';
import '../models/log_entry.dart';
import '../models/agent_trace.dart';

class IncidentProvider extends ChangeNotifier {
  final List<Incident> _incidents = [];
  final Map<String, List<LogEntry>> _streamLogs = {};
  Incident? _currentIncident;
  bool _isLoading = false;
  bool _isSystemOnline = false;
  String? _errorMessage;

  // Active stream subscriptions
  final Map<String, StreamSubscription<LogEntry>> _subscriptions = {};

  Timer? _debounceTimer;

  List<Incident> get incidents => _incidents;
  Map<String, List<LogEntry>> get streamLogs => _streamLogs;
  Incident? get currentIncident => _currentIncident;
  bool get isLoading => _isLoading;
  bool get isSystemOnline => _isSystemOnline;
  String? get errorMessage => _errorMessage;

  List<LogEntry> getLogsFor(String incidentId) => _streamLogs[incidentId] ?? [];

  void _debouncedNotify() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), notifyListeners);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<void> checkHealth() async {
    final result = await CiroApi.checkHealth();
    _isSystemOnline = result['status'] == 'ok';
    notifyListeners();
  }

  void _mergeIncidents(List<Incident> incoming) {
    for (final inc in incoming) {
      final idx = _incidents.indexWhere((e) => e.id == inc.id);
      if (idx >= 0) {
        _incidents[idx] = inc;
      } else {
        _incidents.add(inc);
      }
    }
    _incidents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> fetchIncidents() async {
    _setLoading(true);
    _setError(null);
    try {
      _mergeIncidents(await CiroApi.getIncidents());
    } catch (e) {
      _setError('Failed to fetch incidents: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<Incident?> fetchIncidentDetail(String incidentId) async {
    _setLoading(true);
    _setError(null);
    try {
      final incident = await CiroApi.getIncidentDetail(incidentId);
      _currentIncident = incident;
      return incident;
    } catch (e) {
      _setError('Failed to fetch incident details: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> simulateScenario(String scenario) async {
    _setLoading(true);
    _setError(null);
    try {
      final result = await CiroApi.simulateScenario(scenario);
      final incidentId = result['_id'] ?? result['id'] ?? result['incident_id'];
      if (incidentId != null) {
        startStream(incidentId);
        return incidentId;
      }
    } catch (e) {
      _setError('Failed to start scenario: $e');
    } finally {
      _setLoading(false);
    }
    return null;
  }

  Future<String?> analyzeSignals({
    required List<String> socialPosts,
    required List<String> manualReports,
    Map<String, dynamic>? weatherOverride,
    Map<String, dynamic>? trafficOverride,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final result = await CiroApi.analyzeSignals(
        socialPosts: socialPosts,
        manualReports: manualReports,
        weatherOverride: weatherOverride,
        trafficOverride: trafficOverride,
      );
      final incidentId = result['_id'] ?? result['id'] ?? result['incident_id'];
      if (incidentId != null) {
        startStream(incidentId);
        return incidentId;
      }
    } catch (e) {
      _setError('Failed to analyze signals: $e');
    } finally {
      _setLoading(false);
    }
    return null;
  }

  void startStream(String incidentId) {
    if (_subscriptions.containsKey(incidentId)) {
      return; // Already streaming
    }

    _streamLogs[incidentId] = [];
    notifyListeners();

    final subscription = CiroApi.streamIncidentLogs(incidentId).listen(
      (LogEntry entry) {
        _streamLogs[incidentId]!.add(entry);
        _debouncedNotify();
        
        // If event indicates completion, refresh details and incidents list
        if (entry.message.toLowerCase().contains('pipeline complete') ||
            entry.type == 'OUTCOME_ASSESSMENT' ||
            entry.type == 'ERROR') {
          _refreshAfterCompletion(incidentId);
        }
      },
      onError: (e) {
        print('Stream error for $incidentId: $e');
      },
      onDone: () {
        _subscriptions.remove(incidentId);
        // Refresh detail and incidents list when stream ends
        _refreshAfterCompletion(incidentId);
      },
    );

    _subscriptions[incidentId] = subscription;
  }

  Future<void> _refreshAfterCompletion(String incidentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        CiroApi.getIncidentDetail(incidentId),
        CiroApi.getIncidents(),
      ]);
      _currentIncident = results[0] as Incident?;
      _mergeIncidents(results[1] as List<Incident>);
    } catch (e) {
      _errorMessage = 'Failed to refresh after completion: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<AgentTrace>> fetchAgentTrace(String incidentId) async {
    try {
      return await CiroApi.getAgentTrace(incidentId);
    } catch (e) {
      _setError('Failed to fetch trace: $e');
      return [];
    }
  }

  @override
  void dispose() {
    for (var sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
