import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;


class GeminiServiceMissions {
  static const String _apiKey = 'Enter your gemini API key'; // Replace with your actual API key
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  Future<List<Map<String, dynamic>>> generateDailyMissions(String selectedLanguage) async {
    try {
      final prompt = '''
        You are a language learning assistant. Generate exactly 3 daily missions for a user learning $selectedLanguage.
        Missions should vary in type and be specific, achievable tasks related to vocabulary, grammar, or usage in $selectedLanguage.
        Examples include:
        - Translation: "Translate 'friend' to $selectedLanguage"
        - Listing: "List 3 greetings in $selectedLanguage"
        - Sentence: "Frame a sentence using 'happy' in $selectedLanguage"
        Return a JSON array of 3 objects, each with:
        - "text": the mission text (e.g., "Translate 'friend' to $selectedLanguage")
        - "type": the mission type ("translate", "list", or "sentence")
        Ensure your response is enclosed in ```json``` markers.
      ''';

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 200},
        }),
      ).timeout(const Duration(seconds: 10), onTimeout: () => throw 'Timeout');

      print('API Status: ${response.statusCode}');
      print('API Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final contentString = data['candidates'][0]['content']['parts'][0]['text'];
        final jsonMatch = RegExp(r'```json\s*(.*?)\s*```', dotAll: true).firstMatch(contentString);
        if (jsonMatch != null) {
          final result = jsonDecode(jsonMatch.group(1)!) as List<dynamic>;
          print('Generated Missions: $result');
          return result.map((item) => item as Map<String, dynamic>).toList();
        }
      }
      return _mockGenerateMissions(selectedLanguage); // Fallback to mock
    } catch (e) {
      print('Exception: $e');
      return _mockGenerateMissions(selectedLanguage);
    }
  }

  Future<bool> verifyMissionAnswer(String userAnswer, String missionText, String missionType, String language) async {
    try {
      String prompt;
      switch (missionType) {
        case 'translate':
          prompt = '''
            You are a language verification expert. The user provided the answer "$userAnswer" for the mission "$missionText" in $language.
            Verify if the translation is correct (case-insensitive). Respond with a JSON object:
            {
              "valid": true/false,
              "details": "Explanation if invalid"
            }
            Ensure your response is enclosed in ```json``` markers.
          ''';
          break;
        case 'list':
          prompt = '''
            You are a language verification expert. The user provided the answer "$userAnswer" for the mission "$missionText" in $language.
            The answer should be a comma-separated list of items (e.g., "word1, word2, word3"). Verify if all items are valid $language words and match the mission's requirement (e.g., greetings, verbs). Respond with a JSON object:
            {
              "valid": true/false,
              "details": "Explanation if invalid"
            }
            Ensure your response is enclosed in ```json``` markers.
          ''';
          break;
        case 'sentence':
          prompt = '''
            You are a language verification expert. The user provided the answer "$userAnswer" for the mission "$missionText" in $language.
            Verify if the sentence is grammatically correct in $language and uses the specified word (if any). Respond with a JSON object:
            {
              "valid": true/false,
              "details": "Explanation if invalid"
            }
            Ensure your response is enclosed in ```json``` markers.
          ''';
          break;
        default:
          return false;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {'temperature': 0.5, 'maxOutputTokens': 200},
        }),
      ).timeout(const Duration(seconds: 10), onTimeout: () => throw 'Timeout');

      print('API Status: ${response.statusCode}');
      print('API Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final contentString = data['candidates'][0]['content']['parts'][0]['text'];
        final jsonMatch = RegExp(r'```json\s*(.*?)\s*```', dotAll: true).firstMatch(contentString);
        if (jsonMatch != null) {
          final result = jsonDecode(jsonMatch.group(1)!);
          print('Verification Result: $result');
          return result['valid'] as bool;
        }
      }
      return _mockVerifyAnswer(userAnswer, missionText, missionType, language); // Fallback to mock
    } catch (e) {
      print('Exception: $e');
      return _mockVerifyAnswer(userAnswer, missionText, missionType, language);
    }
  }

  List<Map<String, dynamic>> _mockGenerateMissions(String language) {
    return [
      {
        'text': "Translate 'friend' to $language",
        'type': 'translate',
      },
      {
        'text': "List 3 greetings in $language",
        'type': 'list',
      },
      {
        'text': "Frame a sentence using 'happy' in $language",
        'type': 'sentence',
      },
    ];
  }

  bool _mockVerifyAnswer(String userAnswer, String missionText, String missionType, String language) {
    final mockAnswers = {
      'English': {
        "Translate 'friend' to English": 'friend',
        "List 3 greetings in English": ['hello', 'hi', 'hey'],
        "Frame a sentence using 'happy' in English": 'I am happy today',
      },
      'German': {
        "Translate 'friend' to German": 'freund',
        "List 3 greetings in German": ['hallo', 'guten tag', 'tschüss'],
        "Frame a sentence using 'happy' in German": 'Ich bin heute glücklich',
      },
      'Spanish': {
        "Translate 'friend' to Spanish": 'amigo',
        "List 3 greetings in Spanish": ['hola', 'adiós', 'buenos días'],
        "Frame a sentence using 'happy' in Spanish": 'Estoy feliz hoy',
      },
      'French': {
        "Translate 'friend' to French": 'ami',
        "List 3 greetings in French": ['salut', 'bonjour', 'au revoir'],
        "Frame a sentence using 'happy' in French": 'Je suis heureux aujourd’hui',
      },
      // Add more languages as needed
    };

    final answers = mockAnswers[language] ?? {};
    switch (missionType) {
      case 'translate':
        return userAnswer.toLowerCase() == (answers[missionText] as String?)?.toLowerCase();
      case 'list':
        final userList = userAnswer.split(',').map((s) => s.trim().toLowerCase()).toList();
        final expectedList = (answers[missionText] as List<String>? ?? []).map((s) => s.toLowerCase()).toList();
        return userList.length >= 3 && userList.every((item) => expectedList.contains(item));
      case 'sentence':
        final expected = (answers[missionText] as String?)?.toLowerCase();
        return userAnswer.toLowerCase().contains('happy') && userAnswer.length > 5; // Basic check
      default:
        return false;
    }
  }
}