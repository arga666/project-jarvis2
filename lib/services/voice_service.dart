import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'gemini_service.dart';
import 'system_actions.dart';

class VoiceService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final GeminiService _gemini = GeminiService();

  bool isGamingMode = false;
  bool isSpeakingCritical = false;
  bool _isBusy = false;

  Future<void> init() async {
    await _stt.initialize(onError: (_) => _restartListeningLoop());

    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.54);
    await _tts.setPitch(1.06);
    await _tts.awaitSpeakCompletion(true);

    final voices = await _tts.getVoices;
    if (voices is List) {
      for (final v in voices) {
        final name = v['name'].toString().toLowerCase();
        if (name.contains('id-id') && (name.contains('dfp') || name.contains('irp') || name.contains('male'))) {
          await _tts.setVoice({'name': v['name'], 'locale': v['locale']});
          break;
        }
      }
    }

    _startWakeWordLoop();
  }

  void _startWakeWordLoop() async {
    if (_isBusy) return;

    await _stt.listen(
      localeId: 'id_ID',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(milliseconds: 900),
      onResult: (result) async {
        final spoken = result.recognizedWords.toLowerCase().trim();
        if (spoken.isEmpty) return;

        if (isSpeakingCritical && spoken.length > 5) {
          await _tts.stop();
          await speak('Eh bro, tolong dengerin gua dulu ga, ini penting banget buat lu!', critical: true);
          return;
        }

        if (!result.finalResult) return;

        if (spoken.contains('tidur dulu') && spoken.contains('main game')) {
          await _enterGamingMode();
          return;
        }

        if (spoken.contains('jarvis') || RegExp(r'\bvis\b').hasMatch(spoken)) {
          if (isGamingMode) {
            await _exitGamingMode();
          }

          final cleanQuery = spoken
              .replaceAll('jarvis', '')
              .replaceAll(RegExp(r'\bvis\b'), '')
              .trim();

          if (cleanQuery.isEmpty) {
            await _updateOrbState('speaking');
            await speak('Yo bro, kenapa? Gua dengerin nih.');
            await _updateOrbState('listening');
          } else {
            await _processCommand(cleanQuery);
          }
        }
      },
    );
  }

  Future<void> _processCommand(String query) async {
    _isBusy = true;
    await _updateOrbState('listening');

    final bool criticalTopic = query.contains('begadang') ||
        query.contains('putusin') ||
        query.contains('berhenti') ||
        query.contains('pinjol');

    await for (final sentence in _gemini.streamResponse(query)) {
      await _updateOrbState('speaking');
      await speak(sentence, critical: criticalTopic);
    }

    await _updateOrbState('idle');
    _isBusy = false;
    _restartListeningLoop();
  }

  Future<void> speak(String text, {bool critical = false}) async {
    isSpeakingCritical = critical;
    await _tts.speak(text);
    isSpeakingCritical = false;
  }

  Future<void> _enterGamingMode() async {
    isGamingMode = true;
    await speak('Oke bro, gua masuk mode hemat RAM dulu. Gas push rank, panggil aja Vis kalau butuh.');
    SystemActions.purgeRamForGaming();
    await FlutterOverlayWindow.shareData('gaming_mode');
    await FlutterOverlayWindow.closeOverlay();
    _restartListeningLoop();
  }

  Future<void> _exitGamingMode() async {
    isGamingMode = false;
    if (!(await FlutterOverlayWindow.isActive())) {
      await FlutterOverlayWindow.showOverlay(
        height: 220,
        width: 220,
        alignment: OverlayAlignment.centerRight,
        enableDrag: true,
      );
    }
    await _updateOrbState('idle');
  }

  Future<void> _updateOrbState(String state) async {
    if (!isGamingMode) {
      await FlutterOverlayWindow.shareData(state);
    }
  }

  void _restartListeningLoop() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_stt.isListening && !_isBusy) {
        _startWakeWordLoop();
      }
    });
  }
}
