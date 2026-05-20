import 'package:flutter/material.dart';

class CrisisMapScreen extends StatefulWidget {
  const CrisisMapScreen({super.key});

  @override
  State<CrisisMapScreen> createState() => _CrisisMapScreenState();
}

class _CrisisMapScreenState extends State<CrisisMapScreen>
    with TickerProviderStateMixin {
  bool _showAfter = false;
  late AnimationController _pulseController;
  late AnimationController _transitionController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _transitionAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _transitionAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  void _toggleView() {
    setState(() {
      _showAfter = !_showAfter;
      if (_showAfter) {
        _transitionController.forward();
      } else {
        _transitionController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crisis Map Visualization',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'G-10 Markaz, Islamabad — Urban Flooding',
                        style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _toggleView,
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
                          _showAfter ? 'AFTER RESPONSE' : 'BEFORE RESPONSE',
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
          ),
          // Map Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pulseAnimation, _transitionAnimation]),
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _CrisisMapPainter(
                        showAfter: _showAfter,
                        pulseValue: _pulseAnimation.value,
                        transitionValue: _transitionAnimation.value,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Info Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _infoCard(Icons.traffic, 'Congestion', _showAfter ? '38%' : '94%',
                    _showAfter ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C)),
                const SizedBox(width: 8),
                _infoCard(Icons.local_hospital, 'Teams', _showAfter ? '4 Active' : '0 Active',
                    _showAfter ? const Color(0xFF2ECC71) : const Color(0xFF8B949E)),
                const SizedBox(width: 8),
                _infoCard(Icons.people, 'Alerted', _showAfter ? '15,000' : '0',
                    _showAfter ? const Color(0xFF2ECC71) : const Color(0xFF8B949E)),
                const SizedBox(width: 8),
                _infoCard(Icons.directions, 'Routes', _showAfter ? '3 Active' : 'Blocked',
                    _showAfter ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _legend(const Color(0xFFE74C3C), 'Crisis Zone'),
                _legend(const Color(0xFFE74C3C).withOpacity(0.7), 'Blocked'),
                _legend(const Color(0xFF2ECC71), 'Alt Route'),
                _legend(const Color(0xFF3498DB), 'Flood'),
                _legend(Colors.orange, 'Rescue'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(label, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10)),
      ],
    );
  }
}

class _CrisisMapPainter extends CustomPainter {
  final bool showAfter;
  final double pulseValue;
  final double transitionValue;

  _CrisisMapPainter({required this.showAfter, required this.pulseValue, required this.transitionValue});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    _drawGrid(canvas, size);
    _drawStreets(canvas, size);
    _drawFloodZone(canvas, size, cx, cy);
    _drawCrisisZone(canvas, cx, cy);
    _drawRoutes(canvas, size, cx, cy);
    if (showAfter) _drawEmergencyUnits(canvas, cx, cy);
    _drawLabels(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.03)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawStreets(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF2A313C)..strokeWidth = 8..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    canvas.drawLine(Offset(0, h * 0.5), Offset(w, h * 0.5), p);
    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h), p);
    canvas.drawLine(Offset(0, h * 0.2), Offset(w, h * 0.2), p);
    canvas.drawLine(Offset(0, h * 0.8), Offset(w, h * 0.8), p);
    p.strokeWidth = 5;
    canvas.drawLine(Offset(w * 0.25, 0), Offset(w * 0.25, h), p);
    canvas.drawLine(Offset(w * 0.75, 0), Offset(w * 0.75, h), p);
  }

  void _drawFloodZone(Canvas canvas, Size size, double cx, double cy) {
    final opacity = showAfter ? 0.05 + 0.1 * (1 - transitionValue) : 0.15;
    final radius = showAfter ? size.width * 0.12 * (1 - transitionValue * 0.6) : size.width * 0.12;
    final fp = Paint()..color = const Color(0xFF3498DB).withOpacity(opacity)..style = PaintingStyle.fill;
    final path = Path()..addOval(Rect.fromCenter(center: Offset(cx - 10, cy + 5), width: radius * 2.5, height: radius * 1.8));
    canvas.drawPath(path, fp);
    canvas.drawPath(path, Paint()..color = const Color(0xFF3498DB).withOpacity(opacity * 2)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  void _drawCrisisZone(Canvas canvas, double cx, double cy) {
    final opacity = showAfter ? 0.15 * (1 - transitionValue) : 0.3 * pulseValue;
    final radius = showAfter ? 35.0 * (1 - transitionValue * 0.5) : 30.0 + 15.0 * pulseValue;
    canvas.drawCircle(Offset(cx, cy), radius * 1.8, Paint()..color = const Color(0xFFE74C3C).withOpacity(opacity * 0.3));
    canvas.drawCircle(Offset(cx, cy), radius, Paint()..color = const Color(0xFFE74C3C).withOpacity(opacity));
    canvas.drawCircle(Offset(cx, cy), radius, Paint()..color = const Color(0xFFE74C3C).withOpacity(opacity * 2)..style = PaintingStyle.stroke..strokeWidth = 2);
    if (!showAfter) canvas.drawCircle(Offset(cx, cy), 5, Paint()..color = const Color(0xFFE74C3C));
  }

  void _drawRoutes(Canvas canvas, Size size, double cx, double cy) {
    final w = size.width;
    final h = size.height;
    if (!showAfter) {
      final bp = Paint()..color = const Color(0xFFE74C3C).withOpacity(0.8)..strokeWidth = 4..strokeCap = StrokeCap.round;
      double dx = w * 0.3;
      while (dx < w * 0.7) {
        canvas.drawLine(Offset(dx, h * 0.5), Offset(dx + 8, h * 0.5), bp);
        dx += 16;
      }
      final xp = Paint()..color = const Color(0xFFE74C3C)..strokeWidth = 3..strokeCap = StrokeCap.round;
      for (final xPos in [w * 0.35, w * 0.65]) {
        canvas.drawLine(Offset(xPos - 8, h * 0.5 - 8), Offset(xPos + 8, h * 0.5 + 8), xp);
        canvas.drawLine(Offset(xPos - 8, h * 0.5 + 8), Offset(xPos + 8, h * 0.5 - 8), xp);
      }
    } else {
      final ap = Paint()..color = Color.fromRGBO(46, 204, 113, 0.7 * transitionValue)..strokeWidth = 4..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
      final p1 = Path()..moveTo(w * 0.15, h * 0.5)..lineTo(w * 0.25, h * 0.5)..lineTo(w * 0.25, h * 0.2)..lineTo(w * 0.75, h * 0.2)..lineTo(w * 0.75, h * 0.5)..lineTo(w * 0.85, h * 0.5);
      canvas.drawPath(p1, ap);
      final p2 = Path()..moveTo(w * 0.15, h * 0.5)..lineTo(w * 0.25, h * 0.5)..lineTo(w * 0.25, h * 0.8)..lineTo(w * 0.75, h * 0.8)..lineTo(w * 0.75, h * 0.5)..lineTo(w * 0.85, h * 0.5);
      canvas.drawPath(p2, ap);
    }
  }

  void _drawEmergencyUnits(Canvas canvas, double cx, double cy) {
    final units = [
      [cx - 60.0, cy - 50.0, 'R-1122', Colors.orange],
      [cx + 65.0, cy - 40.0, 'NDMA', Colors.orange],
      [cx - 50.0, cy + 55.0, 'CDA', Colors.amber],
      [cx + 55.0, cy + 50.0, 'Police', Colors.blue],
    ];
    for (final u in units) {
      final x = u[0] as double;
      final y = u[1] as double;
      final label = u[2] as String;
      final color = u[3] as Color;
      canvas.drawCircle(Offset(x, y), 18, Paint()..color = color.withOpacity(0.3 * transitionValue));
      canvas.drawCircle(Offset(x, y), 18, Paint()..color = color.withOpacity(0.8 * transitionValue)..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawCircle(Offset(x, y), 6, Paint()..color = color.withOpacity(transitionValue));
      final tp = TextPainter(text: TextSpan(text: label, style: TextStyle(color: color.withOpacity(transitionValue), fontSize: 9, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y + 22));
    }
  }

  void _drawLabels(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    void label(double x, double y, String text, {bool bold = false, bool center = false}) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: Colors.white.withOpacity(bold ? 0.9 : 0.4), fontSize: bold ? 13 : 10, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(center ? x - tp.width / 2 : x, y));
    }
    label(w * 0.5, h * 0.5 - 60, 'G-10 Markaz', bold: true, center: true);
    label(w * 0.08, h * 0.5 + 14, 'Fazl-e-Haq Road');
    label(w * 0.08, h * 0.2 + 10, 'Constitution Ave');
    label(w * 0.08, h * 0.8 + 10, 'IJP Road');
    label(w * 0.25 + 4, h * 0.05, 'G-9');
    label(w * 0.75 + 4, h * 0.05, 'G-8');
    label(w * 0.5, h * 0.92, 'Islamabad Highway', center: true);
    // Status
    final sc = showAfter ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);
    final st = showAfter ? 'RESPONSE ACTIVE' : 'CRISIS DETECTED';
    final stp = TextPainter(text: TextSpan(text: st, style: TextStyle(color: sc, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)), textDirection: TextDirection.ltr)..layout();
    stp.paint(canvas, Offset(w / 2 - stp.width / 2, 16));
  }

  @override
  bool shouldRepaint(covariant _CrisisMapPainter old) =>
      old.showAfter != showAfter || old.pulseValue != pulseValue || old.transitionValue != transitionValue;
}
