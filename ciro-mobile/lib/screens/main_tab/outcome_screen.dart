import 'package:flutter/material.dart';

class OutcomeScreen extends StatefulWidget {
  const OutcomeScreen({super.key});

  @override
  State<OutcomeScreen> createState() => _OutcomeScreenState();
}

class _OutcomeScreenState extends State<OutcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showAfter = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _showAfter = !_showAfter;
      if (_showAfter) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final t = _animation.value;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Outcome Visualization',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        SizedBox(height: 4),
                        Text('Before vs After — CIRO Response Impact',
                            style: TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _showAfter
                            ? const Color(0xFF2ECC71).withOpacity(0.2)
                            : const Color(0xFFE74C3C).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _showAfter ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showAfter ? Icons.check_circle : Icons.warning,
                            color: _showAfter ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _showAfter ? 'AFTER' : 'BEFORE',
                            style: TextStyle(
                              color: _showAfter ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Impact Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2ECC71).withOpacity(0.1 * t),
                      const Color(0xFF161B22),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Color.lerp(const Color(0xFFE74C3C), const Color(0xFF2ECC71), t)!.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.insights, color: Color.lerp(const Color(0xFFE74C3C), const Color(0xFF2ECC71), t), size: 28),
                        const SizedBox(width: 12),
                        const Text('Impact Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _showAfter
                          ? 'CIRO reduced response time by 40% and coordinated 4 emergency teams simultaneously. 15,000 citizens were alerted within 10 minutes of crisis detection.'
                          : 'No coordinated response active. Crisis is unmanaged. Citizens are unaware. Emergency teams have not been dispatched.',
                      style: TextStyle(
                        color: _showAfter ? const Color(0xFF2ECC71).withOpacity(0.9) : const Color(0xFFE74C3C).withOpacity(0.9),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Metric Cards Grid
              _metricCard(
                icon: Icons.traffic,
                label: 'Traffic Congestion',
                beforeVal: '94%',
                afterVal: '38%',
                progress: t,
                beforePct: 0.94,
                afterPct: 0.38,
              ),
              const SizedBox(height: 12),
              _metricCard(
                icon: Icons.local_hospital,
                label: 'Emergency Teams Deployed',
                beforeVal: '0',
                afterVal: '4',
                progress: t,
                beforePct: 0.0,
                afterPct: 1.0,
              ),
              const SizedBox(height: 12),
              _metricCard(
                icon: Icons.people,
                label: 'Citizens Alerted',
                beforeVal: '0',
                afterVal: '15,000',
                progress: t,
                beforePct: 0.0,
                afterPct: 0.75,
              ),
              const SizedBox(height: 12),
              _metricCard(
                icon: Icons.assignment,
                label: 'Incident Tickets',
                beforeVal: '0',
                afterVal: '1',
                progress: t,
                beforePct: 0.0,
                afterPct: 0.5,
              ),
              const SizedBox(height: 12),
              _metricCard(
                icon: Icons.directions,
                label: 'Roads Operational',
                beforeVal: 'Blocked',
                afterVal: 'Rerouted',
                progress: t,
                beforePct: 0.0,
                afterPct: 0.85,
              ),
              const SizedBox(height: 24),

              // Action Timeline
              const Text('Response Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              ..._buildTimeline(t),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String label,
    required String beforeVal,
    required String afterVal,
    required double progress,
    required double beforePct,
    required double afterPct,
  }) {
    final currentPct = beforePct + (afterPct - beforePct) * progress;
    final barColor = Color.lerp(const Color(0xFFE74C3C), const Color(0xFF2ECC71), progress)!;
    final displayVal = progress > 0.5 ? afterVal : beforeVal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: barColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: barColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  displayVal,
                  key: ValueKey(displayVal),
                  style: TextStyle(color: barColor, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: currentPct.clamp(0.0, 1.0),
                backgroundColor: Colors.white.withOpacity(0.05),
                color: barColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Before: $beforeVal', style: TextStyle(color: const Color(0xFFE74C3C).withOpacity(0.6), fontSize: 11)),
              Text('After: $afterVal', style: TextStyle(color: const Color(0xFF2ECC71).withOpacity(0.6), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTimeline(double t) {
    final events = [
      {'time': 'T+0:00', 'label': 'Crisis detected — Social media signals ingested', 'icon': Icons.sensors, 'threshold': 0.0},
      {'time': 'T+0:02', 'label': 'Signal Ingestor processed 5 signals', 'icon': Icons.input, 'threshold': 0.1},
      {'time': 'T+0:05', 'label': 'Situation assessed: HIGH severity, 85% confidence', 'icon': Icons.analytics, 'threshold': 0.25},
      {'time': 'T+0:07', 'label': 'Emergency dispatch: 4 teams ordered to G-10', 'icon': Icons.local_hospital, 'threshold': 0.4},
      {'time': 'T+0:08', 'label': 'Traffic routes updated via Google Maps / Waze', 'icon': Icons.directions, 'threshold': 0.55},
      {'time': 'T+0:10', 'label': '15,000 citizens alerted via SMS + Push', 'icon': Icons.notifications_active, 'threshold': 0.7},
      {'time': 'T+0:12', 'label': 'Incident ticket CIR-2025-001 created & assigned', 'icon': Icons.assignment_turned_in, 'threshold': 0.85},
    ];

    return events.map((e) {
      final threshold = e['threshold'] as double;
      final isActive = t >= threshold;
      final opacity = isActive ? 1.0 : 0.3;
      final color = isActive ? const Color(0xFF2ECC71) : const Color(0xFF8B949E);

      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline dot and line
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isActive ? color : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                  ),
                  Container(width: 2, height: 36, color: color.withOpacity(0.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Time badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                e['time'] as String,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Opacity(
                opacity: opacity,
                child: Row(
                  children: [
                    Icon(e['icon'] as IconData, color: color, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        e['label'] as String,
                        style: TextStyle(color: Colors.white.withOpacity(opacity), fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
