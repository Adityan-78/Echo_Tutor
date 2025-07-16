import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  late FlutterTts _flutterTts;
  bool _isTtsInitialized = false;

  VoiceService() {
    _flutterTts = FlutterTts();
  }

  Future<void> initializeTts() async {
    if (!_isTtsInitialized) {
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isTtsInitialized = true;
      print("TTS initialized with default settings.");
    }
  }

  Future<void> speak(String text, String language) async {
    if (!_isTtsInitialized) await initializeTts();
    final langCode = _getTtsLocaleId(language);
    print("Speaking: '$text' in language: $language ($langCode)");
    await _flutterTts.setLanguage(langCode);
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  String _getTtsLocaleId(String language) {
    final localeIds = {
      'Spanish': 'es-ES',
      'French': 'fr-FR',
      'German': 'de-DE',
      'Italian': 'it-IT',
      'Portuguese': 'pt-PT',
      'Hindi': 'hi-IN',
      'Japanese': 'ja-JP',
      'Korean': 'ko-KR',
      'Chinese': 'zh-CN',
      'Arabic': 'ar-SA',
      'Russian': 'ru-RU',
      'English': 'en-US',
      'Tamil': 'ta-IN',
      'Telugu': 'te-IN',
      'Malayalam': 'ml-IN',
    };
    return localeIds[language] ?? 'en-US';
  }
}