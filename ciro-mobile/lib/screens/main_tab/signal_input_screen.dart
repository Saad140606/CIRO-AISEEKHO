import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/incident_provider.dart';
import '../logs_tab/incident_detail_screen.dart';

class SignalInputScreen extends StatefulWidget {
  const SignalInputScreen({super.key});

  @override
  State<SignalInputScreen> createState() => _SignalInputScreenState();
}

class _SignalInputScreenState extends State<SignalInputScreen> {
  final List<TextEditingController> _socialControllers = [
    TextEditingController(text: "G-10 mein pani bhar gaya hai, gaariyan phans gayi hain")
  ];
  final List<TextEditingController> _manualControllers = [
    TextEditingController()
  ];

  bool _weatherEnabled = false;
  final TextEditingController _rainfallCtrl = TextEditingController(text: "0");
  String _weatherAlert = 'low';

  bool _trafficEnabled = false;
  String _trafficCongestion = 'medium';
  final TextEditingController _trafficAreaCtrl = TextEditingController();

  void _submit() async {
    final socialPosts = _socialControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    final manualReports = _manualControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

    Map<String, dynamic>? weatherOverride;
    if (_weatherEnabled) {
      weatherOverride = {
        'rainfall_mm': double.tryParse(_rainfallCtrl.text) ?? 0,
        'alert_level': _weatherAlert,
      };
    }

    Map<String, dynamic>? trafficOverride;
    if (_trafficEnabled) {
      trafficOverride = {
        'congestion_level': _trafficCongestion,
        'affected_area': _trafficAreaCtrl.text,
      };
    }

    final provider = context.read<IncidentProvider>();
    final incidentId = await provider.analyzeSignals(
      socialPosts: socialPosts,
      manualReports: manualReports,
      weatherOverride: weatherOverride,
      trafficOverride: trafficOverride,
    );

    if (incidentId != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IncidentDetailScreen(incidentId: incidentId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<IncidentProvider>().isLoading;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ListView(
        children: [
          const Text('Manual Signal Input', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 24),
          
          _buildDynamicListSection('Social Media Posts', _socialControllers),
          const SizedBox(height: 24),
          
          _buildDynamicListSection('Manual Reports', _manualControllers),
          const SizedBox(height: 24),

          _buildWeatherSection(),
          const SizedBox(height: 24),

          _buildTrafficSection(),
          const SizedBox(height: 32),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: isLoading ? null : _submit,
            child: isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Text('ANALYZE SIGNALS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDynamicListSection(String title, List<TextEditingController> controllers) {
    return Card(
      color: const Color(0xFF161B22),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(title, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFF2ECC71)),
                    onPressed: () {
                      setState(() {
                        controllers.add(TextEditingController());
                      });
                    },
                  ),
                ),
              ],
            ),
            ...controllers.asMap().entries.map((entry) {
              int idx = entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: entry.value,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Enter text here...',
                          hintStyle: TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Color(0xFF0D1117),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () {
                          setState(() {
                            controllers.removeAt(idx);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            })
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherSection() {
    return Card(
      color: const Color(0xFF161B22),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text('Weather Override', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                Switch(
                  value: _weatherEnabled,
                  activeThumbColor: const Color(0xFF2ECC71),
                  onChanged: (val) => setState(() => _weatherEnabled = val),
                ),
              ],
            ),
            if (_weatherEnabled)
              Column(
                children: [
                  TextField(
                    controller: _rainfallCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Rainfall (mm)', filled: true, fillColor: Color(0xFF0D1117)),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _weatherAlert,
                    dropdownColor: const Color(0xFF0D1117),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Alert Level', filled: true, fillColor: Color(0xFF0D1117)),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                      DropdownMenuItem(value: 'extreme', child: Text('Extreme')),
                    ],
                    onChanged: (val) => setState(() => _weatherAlert = val!),
                  )
                ],
              )
          ],
        ),
      ),
    );
  }

  Widget _buildTrafficSection() {
    return Card(
      color: const Color(0xFF161B22),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text('Traffic Override', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                Switch(
                  value: _trafficEnabled,
                  activeThumbColor: const Color(0xFF2ECC71),
                  onChanged: (val) => setState(() => _trafficEnabled = val),
                ),
              ],
            ),
            if (_trafficEnabled)
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _trafficCongestion,
                    dropdownColor: const Color(0xFF0D1117),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Congestion Level', filled: true, fillColor: Color(0xFF0D1117)),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'heavy', child: Text('Heavy')),
                      DropdownMenuItem(value: 'standstill', child: Text('Standstill')),
                    ],
                    onChanged: (val) => setState(() => _trafficCongestion = val!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _trafficAreaCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Affected Area', filled: true, fillColor: Color(0xFF0D1117)),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }
}
