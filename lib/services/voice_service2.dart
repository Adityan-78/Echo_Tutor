import 'package:flutter_tts/flutter_tts.dart';

class VoiceService2 {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  VoiceService() {
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    try {
      await _tts.awaitSpeakCompletion(true); // Ensure completion tracking
      await _tts.setSpeechRate(0.5); // Slower for clarity
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _isInitialized = true;
      print('TTS initialized successfully');
    } catch (e) {
      print('TTS init failed: $e');
      _isInitialized = false;
    }
  }

  Future<void> speak(String text, String language) async {
    if (!_isInitialized) {
      print('TTS not ready, initializing...');
      await _initializeTts();
    }
    if (_isInitialized) {
      final localeId = _getLocaleId(language);
      try {
        await _tts.setLanguage(localeId);
        await _tts.speak(text);
        print('Speaking: "$text" in $localeId');
      } catch (e) {
        print('Speak error: $e');
      }
    } else {
      print('TTS failed to initialize, cannot speak: $text');
    }
  }

  Future<void> stop() async {
    if (_isInitialized) {
      await _tts.stop();
      print('TTS stopped');
    }
  }

  String _getLocaleId(String language) {
    const localeIds = {
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