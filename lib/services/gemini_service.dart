import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/constants.dart';
import '../core/database_helper.dart';
import 'system_actions.dart';

class GeminiService {
  late final GenerativeModel _model;
  late ChatSession _chat;

  GeminiService() {
    final setAlarmDecl = FunctionDeclaration(
      'set_alarm',
      'Pasang alarm otomatis di HP user berdasarkan jam dan alasan.',
      Schema.object(
        properties: {
          'hour': Schema.integer(description: 'Jam format 24-jam (0-23)'),
          'minute': Schema.integer(description: 'Menit (0-59)'),
          'label': Schema.string(description: 'Alasan atau nama alarm'),
        },
        requiredProperties: ['hour', 'minute', 'label'],
      ),
    );

    final recallHistoryDecl = FunctionDeclaration(
      'recall_history',
      'Cari obrolan masa lalu jika user minta mengulang omongan sebelumnya.',
      Schema.object(
        properties: {
          'keyword': Schema.string(description: 'Kata kunci topik obrolan'),
        },
        requiredProperties: ['keyword'],
      ),
    );

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: AppConstants.geminiApiKey,
      systemInstruction: Content.system(AppConstants.systemInstruction),
      tools: [
        Tool(functionDeclarations: [setAlarmDecl, recallHistoryDecl])
      ],
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 180,
      ),
    );

    _chat = _model.startChat();
  }

  Stream<String> streamResponse(String userPrompt) async* {
    await DatabaseHelper.instance.insertLog('User', userPrompt);

    final responseStream = _chat.sendMessageStream(Content.text(userPrompt));
    StringBuffer fullReply = StringBuffer();
    StringBuffer sentenceBuffer = StringBuffer();

    await for (final chunk in responseStream) {
      if (chunk.functionCalls.isNotEmpty) {
        for (final call in chunk.functionCalls) {
          if (call.name == 'set_alarm') {
            final hour = (call.args['hour'] as num).toInt();
            final minute = (call.args['minute'] as num).toInt();
            final label = call.args['label'].toString();
            await SystemActions.setNativeAlarm(hour: hour, minute: minute, label: label);

            final confirm = 'Sip bro, alarm jam ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} buat $label udah gua pasangin.';
            fullReply.write(confirm);
            yield confirm;
          } else if (call.name == 'recall_history') {
            final keyword = call.args['keyword'].toString();
            final logs = await DatabaseHelper.instance.searchMemory(keyword);
            final memoryText = logs.isEmpty
                ? 'Gak ketemu di riwayat.'
                : logs.map((e) => '${e['role']}: ${e['message']}').join(' | ');

            final followUp = await _chat.sendMessage(
              Content.functionResponse(call.name, {'result': memoryText}),
            );
            if (followUp.text != null) {
              fullReply.write(followUp.text!);
              yield followUp.text!;
            }
          }
        }
      }

      if (chunk.text != null) {
        fullReply.write(chunk.text!);
        sentenceBuffer.write(chunk.text!);

        String current = sentenceBuffer.toString();
        if (current.contains(RegExp(r'[.!?]\s'))) {
          yield current.trim();
          sentenceBuffer.clear();
        }
      }
    }

    if (sentenceBuffer.isNotEmpty) {
      yield sentenceBuffer.toString().trim();
    }

    if (fullReply.isNotEmpty) {
      await DatabaseHelper.instance.insertLog('Jarvis', fullReply.toString());
    }
  }
}
