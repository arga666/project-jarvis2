import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'voice_service.dart';

Future<void> initializeBackgroundEngine() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onBackgroundStart,
      autoStart: true,
      isForegroundMode: true,
      foregroundServiceNotificationId: 888,
      initialNotificationTitle: 'Jarvis Active',
      initialNotificationContent: 'Standby dengerin panggilan "Vis"...',
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

@pragma('vm:entry-point')
void onBackgroundStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final voiceService = VoiceService();
  await voiceService.init();

  Timer.periodic(const Duration(minutes: 15), (timer) async {
    if (voiceService.isGamingMode) return;

    final prefs = await SharedPreferences.getInstance();
    final sleepHour = prefs.getInt('sleep_hour') ?? 23;
    final now = DateTime.now();

    if (now.hour >= sleepHour || now.hour < 4) {
      await voiceService.speak(
        'Woy bro, udah lewat jam tidur lu nih. Jangan begadang mulu elah, kasihan badan lu besok pagi. Istirahat sekarang ya.',
        critical: true,
      );
    }
  });
}
