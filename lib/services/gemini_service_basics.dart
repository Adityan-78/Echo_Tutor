import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiServiceBasics {
  static const String _apiKey = 'Enter your gemini API key';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  Future<List<Map<String, String>>> _fetchFromGemini(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {'parts': [{'text': prompt}]}
          ],
          'generationConfig': {
            'temperature': 0.5,
            'maxOutputTokens': 2048, // Increased limit
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final contentString =
        data['candidates'][0]['content']['parts'][0]['text'].trim();
        print('Raw content string: "$contentString"');

        // Clean up JSON response
        String jsonString = contentString
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim()
            .replaceAll(RegExp(r'\s*\n\s*'), ''); // Remove extra newlines/spaces

        print('Cleaned JSON string: "$jsonString"');

        if (!jsonString.startsWith('[') || !jsonString.endsWith(']')) {
          print("⚠️ Invalid JSON structure received.");
          return [];
        }

        try {
          final rawList = jsonDecode(jsonString) as List<dynamic>;
          return rawList.map((item) {
            final map = item as Map<String, dynamic>;
            return {
              'text': map['text']?.toString() ?? '',
              'translation': map['translation']?.toString() ?? '',
              'pronunciation': map['pronunciation']?.toString() ?? '',
            };
          }).toList();
        } catch (e) {
          print("⚠️ JSON parsing failed: $e");
          return [];
        }
      }

      print("❌ Gemini API failed: ${response.statusCode} - ${response.body}");
      return [];
    } catch (e) {
      print("Error fetching from Gemini: $e");
      return [];
    }
  }

  Future<List<Map<String, String>>> getAlphabets(String language) async {
    final prompt = '''
      You are a language learning assistant. For the language "$language", provide the full alphabet in chronological order.
      For each letter:
      - "text" is the native letter (e.g., "अ" for Hindi).
      - "translation" is the English name or sound of the letter (e.g., "a").
      - "pronunciation" is the phonetic spelling (e.g., "/ə/").
      Return a **compact minified JSON array**, no newlines or extra characters, enclosed in ```json markers.
      Example:
      ```json [{"text":"अ","translation":"a","pronunciation":"/ə/"},{"text":"आ","translation":"aa","pronunciation":"/aː/"}] ```
    ''';
    return await _fetchFromGemini(prompt);
  }

  Future<List<Map<String, String>>> getNumbers(String language, int batchIndex) async {
    final start = batchIndex * 5 + 1;
    final end = start + 4;

    String prompt;

    if (language.toLowerCase() == "hindi") {
      prompt = '''
      You are a language learning assistant. Provide Hindi numbers from $start to $end in valid JSON format.
      Each entry must include:
      - "text": Hindi number in Devanagari script (e.g., "पाँच")
      - "translation": English number word (e.g., "five")
      - "pronunciation": simplified Hindi pronunciation using Latin characters (e.g., "paanch")
      Format: a single-line compact JSON array enclosed in ```json block.
      Example:
      ```json [{"text":"एक","translation":"one","pronunciation":"ek"},{"text":"दो","translation":"two","pronunciation":"do"}] ```
      ⚠️ Don't include extra explanation or line breaks.
    ''';
    } else {
      prompt = '''
      You are a language learning assistant. For the language "$language", provide numbers from $start to $end:
      - "text": the number in the target language (e.g., "cinco" for Spanish, "五" for Japanese).
      - "translation": the English number word (e.g., "five").
      - "pronunciation": phonetic spelling (e.g., "/ˈsɪŋ.koʊ/" or "/paːntʃ/").
      Return a valid compact JSON array with no line breaks, enclosed in ```json markers.
    ''';
    }

    return await _fetchFromGemini(prompt);
  }

  Future<List<Map<String, String>>> getBasicWords(String language, int batchIndex) async {
    final start = batchIndex * 5 + 1;
    final prompt = '''
      You are a language learning assistant. For the language "$language", provide 5 unique basic words (starting from word $start).
      - "text": word in the target language.
      - "translation": English meaning.
      - "pronunciation": phonetic spelling.
      Ensure variety and beginner-level relevance (e.g., greetings, objects).
      Return a compact minified JSON array enclosed in ```json markers.
    ''';
    return await _fetchFromGemini(prompt);
  }
}
