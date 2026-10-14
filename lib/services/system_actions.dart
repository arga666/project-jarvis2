import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/painting.dart';

class SystemActions {
  static Future<void> setNativeAlarm({
    required int hour,
    required int minute,
    required String label,
  }) async {
    final intent = AndroidIntent(
      action: 'android.intent.action.SET_ALARM',
      arguments: <String, dynamic>{
        'android.intent.extra.alarm.HOUR': hour,
        'android.intent.extra.alarm.MINUTES': minute,
        'android.intent.extra.alarm.MESSAGE': label,
        'android.intent.extra.alarm.SKIP_UI': true,
      },
    );
    await intent.launch();
  }

  static void purgeRamForGaming() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}
