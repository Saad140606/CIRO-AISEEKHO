import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/incident.dart';
import '../models/log_entry.dart';
import '../models/agent_trace.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
class CiroApi {
  // Use 10.0.2.2 for Android emulator to reach localhost
  static String get baseUrl => dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:8000';

  // 1. POST /api/analyze
  static Future<Map<String, dynamic>> analyzeSignals({
    required List<String> socialPosts,
    required List<String> manualReports,
    Map<String, dynamic>? weatherOverride,
    Map<String, dynamic>? trafficOverride,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/analyze'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'social_posts': socialPosts,
        'manual_reports': manualReports,
        'weather_override': weatherOverride,
        'traffic_override': trafficOverride,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 202) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to analyze signals: ${response.statusCode}');
    }
  }

  // 2. POST /api/simulate/scenario
  static Future<Map<String, dynamic>> simulateScenario(String scenario) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/simulate/scenario'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'scenario': scenario}),
    );

    if (response.statusCode == 200 || response.statusCode == 202) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to simulate scenario: ${response.statusCode}');
    }
  }

  // 3. GET /api/stream/{incident_id} (SSE)
  static Stream<LogEntry> streamIncidentLogs(String incidentId) async* {
    final client = http.Client();
    final request = http.Request('GET', Uri.parse('$baseUrl/api/stream/$incidentId'));
    request.headers['Accept'] = 'text/event-stream';

    try {
      final response = await client.send(request);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to connect to stream: ${response.statusCode}');
      }

      await for (var chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.startsWith('data: ')) {
          final dataString = chunk.substring(6).trim();
          if (dataString.isNotEmpty && dataString != '[DONE]') {
            try {
              final jsonData = jsonDecode(dataString);
              yield LogEntry.fromJson(jsonData);
            } catch (e) {
              // Ignore malformed json
              print('Error parsing SSE data: $e');
            }
          }
        }
      }
    } finally {
      client.close();
    }
  }

  // 4. GET /api/incidents
  static Future<List<Incident>> getIncidents() async {
    final response = await http.get(Uri.parse('$baseUrl/api/incidents'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Incident.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load incidents');
    }
  }

  // 5. GET /api/incidents/{incident_id}
  static Future<Incident> getIncidentDetail(String incidentId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/incidents/$incidentId'));

    if (response.statusCode == 200) {
      return Incident.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load incident details');
    }
  }

  // 6. GET /api/incidents/{incident_id}/trace
  static Future<List<AgentTrace>> getAgentTrace(String incidentId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/incidents/$incidentId/trace'));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      List<dynamic> traceList;
      if (decoded is List) {
        traceList = decoded;
      } else if (decoded is Map<String, dynamic>) {
        traceList = decoded['trace'] ?? [];
      } else {
        traceList = [];
      }
      return traceList.map((json) => AgentTrace.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load agent trace');
    }
  }

  // 7. GET /api/health
  static Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/health')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {
      // Return error structure handled by frontend
    }
    return {'status': 'offline', 'error': 'Could not connect to backend'};
  }
}
