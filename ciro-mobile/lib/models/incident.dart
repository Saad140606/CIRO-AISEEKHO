class Incident {
  final String id;
  final String crisisType;
  final String severity;
  final String confidence;
  final String affectedArea;
  final String status;
  final String createdAt;
  
  final List<String> impacts;
  final List<ActionItem> actions;
  final List<SimulationStep> simulations;
  final Map<String, dynamic>? beforeState;
  final Map<String, dynamic>? afterState;
  final String? outcomeSummary;
  
  Incident({
    required this.id,
    required this.crisisType,
    required this.severity,
    required this.confidence,
    required this.affectedArea,
    required this.status,
    required this.createdAt,
    this.impacts = const [],
    this.actions = const [],
    this.simulations = const [],
    this.beforeState,
    this.afterState,
    this.outcomeSummary,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    // Extract nested impact data if present
    List<String> parsedImpacts = [];
    if (json.containsKey('situation_assessment')) {
      final sa = json['situation_assessment'] as Map<String, dynamic>? ?? {};
      final impactList = sa['impact_analysis'] as List<dynamic>? ?? [];
      parsedImpacts = impactList.map((e) => e.toString()).toList();
    }

    // Extract action plan
    List<ActionItem> parsedActions = [];
    List<SimulationStep> parsedSimulations = [];
    Map<String, dynamic>? bState;
    Map<String, dynamic>? aState;
    String? oSummary;

    if (json.containsKey('response_plan')) {
      final rp = json['response_plan'] as Map<String, dynamic>? ?? {};
      
      final apList = rp['action_plan'] as List<dynamic>? ?? [];
      parsedActions = apList.map((e) => ActionItem.fromJson(e as Map<String, dynamic>)).toList();
      
      final simList = rp['simulation_results'] as List<dynamic>? ?? [];
      parsedSimulations = simList.map((e) => SimulationStep.fromJson(e as Map<String, dynamic>)).toList();
      
      bState = rp['before_state'] as Map<String, dynamic>?;
      aState = rp['after_state'] as Map<String, dynamic>?;
      oSummary = rp['outcome_summary'] as String?;
    }

    return Incident(
      id: json['_id'] ?? json['id'] ?? json['incident_id'] ?? 'Unknown',
      crisisType: json['crisis_type'] ?? 'Unknown Crisis',
      severity: json['severity'] ?? 'LOW',
      confidence: json['confidence'] ?? '0%',
      affectedArea: json['affected_area'] ?? 'Unknown Location',
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] ?? '',
      impacts: parsedImpacts,
      actions: parsedActions,
      simulations: parsedSimulations,
      beforeState: bState,
      afterState: aState,
      outcomeSummary: oSummary,
    );
  }
}

class ActionItem {
  final String actionId;
  final String type;
  final String priority;
  final String description;
  final String target;
  final String rationale;

  ActionItem({
    required this.actionId,
    required this.type,
    required this.priority,
    required this.description,
    required this.target,
    required this.rationale,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      actionId: json['action_id'] ?? '',
      type: json['type'] ?? '',
      priority: json['priority'] ?? '',
      description: json['description'] ?? '',
      target: json['target'] ?? '',
      rationale: json['rationale'] ?? '',
    );
  }
}

class SimulationStep {
  final String actionId;
  final String toolUsed;
  final String status;
  final String outcome;
  final String timestamp;
  final String log;

  SimulationStep({
    required this.actionId,
    required this.toolUsed,
    required this.status,
    required this.outcome,
    required this.timestamp,
    required this.log,
  });

  factory SimulationStep.fromJson(Map<String, dynamic> json) {
    return SimulationStep(
      actionId: json['action_id'] ?? '',
      toolUsed: json['tool_used'] ?? '',
      status: json['status'] ?? '',
      outcome: json['outcome'] ?? '',
      timestamp: json['timestamp'] ?? '',
      log: json['log'] ?? '',
    );
  }
}
