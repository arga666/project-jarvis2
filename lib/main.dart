import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/database_helper.dart';
import 'services/background_engine.dart';
import 'ui/overlay_orb.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundEngine();
  runApp(const JarvisApp());
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayOrbWidget(),
    ),
  );
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jarvis Control & History',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050B14),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF2B72D6)),
      ),
      home: const HistoryAndControlScreen(),
    );
  }
}

class HistoryAndControlScreen extends StatefulWidget {
  const HistoryAndControlScreen({super.key});

  @override
  State<HistoryAndControlScreen> createState() => _HistoryAndControlScreenState();
}

class _HistoryAndControlScreenState extends State<HistoryAndControlScreen> {
  final FlutterTts _replayTts = FlutterTts();
  List<Map<String, dynamic>> _logs = [];
  int _sleepHour = 23;

  @override
  void initState() {
    super.initState();
    _initPermissionsAndData();
  }

  Future<void> _initPermissionsAndData() async {
    await [
      Permission.microphone,
      Permission.ignoreBatteryOptimizations,
      Permission.scheduleExactAlarm,
    ].request();

    if (!(await FlutterOverlayWindow.isPermissionGranted())) {
      await FlutterOverlayWindow.requestPermission();
    }

    if (!(await FlutterOverlayWindow.isActive())) {
      await FlutterOverlayWindow.showOverlay(
        height: 200,
        width: 200,
        alignment: OverlayAlignment.centerRight,
        enableDrag: true,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    _sleepHour = prefs.getInt('sleep_hour') ?? 23;
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await DatabaseHelper.instance.getAllLogs();
    setState(() => _logs = data);
  }

  Future<void> _updateSleepHour(int hour) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sleep_hour', hour);
    setState(() => _sleepHour = hour);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: const Text('Jarvis ("Vis") — Log & Memory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF0E223D),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Batas Jam Tidur Malam:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                DropdownButton<int>(
                  value: _sleepHour,
                  items: [21, 22, 23, 0, 1].map((h) {
                    return DropdownMenuItem(
                      value: h,
                      child: Text('${h.toString().padLeft(2, '0')}:00 WIB'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) _updateSleepHour(val);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _logs.isEmpty
                ? const Center(child: Text('Belum ada obrolan. Panggil "Vis" buat mulai!'))
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final item = _logs[index];
                      final isJarvis = item['role'] == 'Jarvis';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isJarvis
                              ? const Color(0xFF1E56A0)
                              : Colors.grey.shade800,
                          child: Text(isJarvis ? 'V' : 'U'),
                        ),
                        title: Text(item['message']),
                        subtitle: Text(item['timestamp'].toString().substring(0, 16)),
                        trailing: IconButton(
                          icon: const Icon(Icons.volume_up, color: Color(0xFF2B72D6)),
                          onPressed: () async {
                            await _replayTts.setLanguage('id-ID');
                            await _replayTts.speak(item['message']);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
