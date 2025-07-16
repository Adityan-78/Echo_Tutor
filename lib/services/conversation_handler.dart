import 'dart:convert';
import 'gemini_service1.dart';
import 'voice_service.dart';

class ConversationHandler {
  final GeminiService1 geminiService;
  final VoiceService voiceService;
  final String language;
  String level;

  ConversationHandler({
    required this.geminiService,
    required this.voiceService,
    required this.language,
    required this.level,
  });

  Future<String> handleUserMessage({
    required String message,
    required String currentStage,
    required List<String> history,
  }) async {
    final response = await geminiService.getLessonContent(
      language,
      level,
      currentStage,
      message,
      history.where((m) => m.startsWith('word:')).map((m) => m.split(': ')[1]).toList(),
    );
    return jsonEncode(response);
  }

  void updateLevel(String newLevel) {
    level = newLevel;
  }
}