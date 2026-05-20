class LogEntry {
  final String id;
  final String type;
  final String agentName;
  final String message;
  final String timestamp;
  final Map<String, dynamic>? data;

  LogEntry({
    required this.id,
    required this.type,
    required this.agentName,
    required this.message,
    required this.timestamp,
    this.data,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['log_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: json['log_type'] ?? 'UNKNOWN',
      agentName: json['agent_name'] ?? 'System',
      message: json['message'] ?? '',
      timestamp: json['timestamp'] ?? '',
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}
