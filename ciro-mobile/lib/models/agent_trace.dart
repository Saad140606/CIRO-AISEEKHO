class AgentTrace {
  final String agent;
  final String status;
  final String outputSummary;
  final String timestamp;
  final Map<String, dynamic>? fullOutput;
  final String? error;

  AgentTrace({
    required this.agent,
    required this.status,
    required this.outputSummary,
    required this.timestamp,
    this.fullOutput,
    this.error,
  });

  factory AgentTrace.fromJson(Map<String, dynamic> json) {
    // Determine a fallback summary if there's an error
    String summary = json['output_summary'] ?? '';
    if (summary.isEmpty && json['error'] != null) {
      summary = 'Error occurred: ${json['error']}';
    }

    return AgentTrace(
      agent: json['agent'] ?? 'Unknown Agent',
      status: json['status'] ?? 'unknown',
      outputSummary: summary,
      timestamp: json['timestamp'] ?? '',
      fullOutput: json['full_output'] as Map<String, dynamic>?,
      error: json['error']?.toString(),
    );
  }
}
