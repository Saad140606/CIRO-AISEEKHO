import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong2.dart';
import 'package:provider/provider.dart';
import '../../providers/incident_provider.dart';
import '../../models/incident.dart';

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
  
  final MapController _mapController = MapController();
  Incident? _lastIncident;

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
    _mapController.dispose();
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

  LatLng _getCoords(String area) {
    final cleanArea = area.toLowerCase();
    if (cleanArea.contains('g-10') || cleanArea.contains('islamabad')) {
      return const LatLng(33.6844, 72.9889);
    } else if (cleanArea.contains('saddar') || cleanArea.contains('karachi')) {
      return const LatLng(24.8607, 67.0011);
    } else if (cleanArea.contains('mm alam') || cleanArea.contains('lahore')) {
      return const LatLng(31.5085, 74.3516);
    }
    return const LatLng(33.6844, 72.9889); // Default to Islamabad G-10
  }

  List<LatLng> _getBlockedRoute(LatLng center) {
    return [
      LatLng(center.latitude - 0.004, center.longitude - 0.004),
      center,
      LatLng(center.latitude + 0.003, center.longitude + 0.003),
    ];
  }

  List<LatLng> _getAltRoute(LatLng center) {
    return [
      LatLng(center.latitude - 0.004, center.longitude - 0.004),
      LatLng(center.latitude - 0.002, center.longitude + 0.004),
      LatLng(center.latitude + 0.004, center.longitude + 0.004),
      LatLng(center.latitude + 0.003, center.longitude + 0.003),
    ];
  }

  Widget _mapUnitIcon(IconData icon, Color color, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 2,
              )
            ],
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IncidentProvider>(context);
    final incident = provider.currentIncident;
    
    // Auto-move map center when active incident changes
    if (incident != _lastIncident) {
      _lastIncident = incident;
      if (incident != null) {
        final coords = _getCoords(incident.affectedArea);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(coords, 14.5);
        });
      }
    }

    final String activeArea = incident?.affectedArea ?? 'G-10 Markaz, Islamabad';
    final String activeCrisis = incident?.crisisType ?? 'Urban Flooding';
    final LatLng center = _getCoords(activeArea);

    final showFloodPolygon = activeCrisis.toLowerCase().contains('flood') || activeCrisis.toLowerCase().contains('flooding');

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Crisis Map Visualization',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$activeArea — $activeCrisis',
                        style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
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
                    final t = _transitionAnimation.value;
                    final pulse = _pulseAnimation.value;

                    return ColorFiltered(
                      // Stunning Dark Theme filter applied over Google Map Tiles
                      colorFilter: const ColorFilter.matrix(<double>[
                        -1.0, 0.0, 0.0, 0.0, 255.0,
                        0.0, -1.0, 0.0, 0.0, 255.0,
                        0.0, 0.0, -1.0, 0.0, 255.0,
                        0.0, 0.0, 0.0, 1.0, 0.0,
                      ]),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 14.5,
                          maxZoom: 18,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: "https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}",
                            userAgentPackageName: 'com.ciro.mobile',
                          ),
                          // Crisis Circle Overlay
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: center,
                                radius: 500,
                                useRadiusInMeter: true,
                                color: const Color(0xFFE74C3C).withOpacity(0.08 * (1 - t * 0.5)),
                                borderColor: const Color(0xFFE74C3C).withOpacity(0.2 * (1 - t * 0.5)),
                                borderStrokeWidth: 2,
                              ),
                              CircleMarker(
                                point: center,
                                radius: 250 * pulse,
                                useRadiusInMeter: true,
                                color: const Color(0xFFE74C3C).withOpacity(0.12 * (1 - t)),
                                borderColor: const Color(0xFFE74C3C).withOpacity(0.3 * (1 - t)),
                                borderStrokeWidth: 1.5,
                              ),
                              if (showFloodPolygon)
                                CircleMarker(
                                  point: LatLng(center.latitude + 0.001, center.longitude - 0.002),
                                  radius: 350,
                                  useRadiusInMeter: true,
                                  color: const Color(0xFF3498DB).withOpacity(0.15 * (1 - t * 0.5)),
                                  borderColor: const Color(0xFF3498DB).withOpacity(0.3 * (1 - t * 0.5)),
                                  borderStrokeWidth: 1.5,
                                ),
                            ],
                          ),
                          // Blocked vs Alternate Routes
                          PolylineLayer(
                            polylines: [
                              // Blocked Route (Red)
                              Polyline(
                                points: _getBlockedRoute(center),
                                color: const Color(0xFFE74C3C).withOpacity(0.8 - (t * 0.6)),
                                strokeWidth: 5.0,
                                isDotted: true,
                              ),
                              // Alternate Route (Green) - fades in on transition
                              if (_showAfter || t > 0.01)
                                Polyline(
                                  points: _getAltRoute(center),
                                  color: const Color(0xFF2ECC71).withOpacity(0.8 * t),
                                  strokeWidth: 5.0,
                                ),
                            ],
                          ),
                          // Dispatch markers (visible after response)
                          if (_showAfter || t > 0.01)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(center.latitude + 0.003, center.longitude - 0.004),
                                  width: 45,
                                  height: 45,
                                  child: Opacity(
                                    opacity: t,
                                    child: _mapUnitIcon(Icons.fire_truck, Colors.orange, "NDMA"),
                                  ),
                                ),
                                Marker(
                                  point: LatLng(center.latitude - 0.002, center.longitude + 0.003),
                                  width: 45,
                                  height: 45,
                                  child: Opacity(
                                    opacity: t,
                                    child: _mapUnitIcon(Icons.local_hospital, const Color(0xFFE74C3C), "Rescue"),
                                  ),
                                ),
                                Marker(
                                  point: LatLng(center.latitude + 0.0045, center.longitude + 0.002),
                                  width: 45,
                                  height: 45,
                                  child: Opacity(
                                    opacity: t,
                                    child: _mapUnitIcon(Icons.local_police, Colors.blue, "Police"),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
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
