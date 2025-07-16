import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiServiceQuiz {
  static const String _apiKey = 'Enter your gemini API key'; // Replace with your actual API key
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  Future<List<Map<String, dynamic>>> generateQuizQuestions(String language, String difficulty) async {
    String prompt = _buildPrompt(language, difficulty);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {'parts': [{'text': prompt}]}
          ],
          'generationConfig': {'temperature': 1.5, 'maxOutputTokens': 2000}, // Max creativity
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final contentString = data['candidates'][0]['content']['parts'][0]['text'];
        final jsonMatch = RegExp(r'```json\s*(.*?)\s*```', dotAll: true).firstMatch(contentString);
        if (jsonMatch != null) {
          final rawList = jsonDecode(jsonMatch.group(1)!) as List<dynamic>;
          return rawList.map((item) => item as Map<String, dynamic>).toList();
        }
      }
      print("❌ Gemini API failed: ${response.statusCode} - ${response.body}");
      return [];
    } catch (e) {
      print("Error fetching quiz questions: $e");
      return [];
    }
  }

  String _buildPrompt(String language, String difficulty) {
    String difficultyDescription;
    String questionTypes;

    switch (difficulty.toLowerCase()) {
      case 'basic':
        difficultyDescription =
        "focus on basic vocabulary from a wide range of topics (e.g., greetings, animals, colors, food, numbers, objects, actions). Include 6 text-based multiple-choice questions and 4 voice-based questions. Randomly mix directions: half from English to $language, half from $language to English.";
        questionTypes = """
          - For text-based multiple-choice: 
            - English to $language: 'question' (English word/phrase), 'correctAnswer' ($language word/phrase), 'options' (4 $language options including the correct one).
            - $language to English: 'question' ($language word/phrase), 'correctAnswer' (English meaning), 'options' (4 English options including the correct one).
          - For voice-based: 
            - English to $language: 'question' (English word/phrase to be spoken), 'correctAnswer' ($language word/phrase), 'options' (4 $language options), 'type' as 'voice', 'direction' as 'toLanguage', 'questionLanguage' as 'English'.
            - $language to English: 'question' ($language word/phrase to be spoken), 'correctAnswer' (English meaning), 'options' (4 English options), 'type' as 'voice', 'direction' as 'toEnglish', 'questionLanguage' as '$language'.
        """;
        break;
      case 'intermediate':
        difficultyDescription =
        "focus on basic sentence formation across diverse contexts (e.g., daily routines, questions, descriptions, emotions). Include 5 text-based multiple-choice questions and 5 voice-based questions. Randomly mix directions: half from English to $language, half from $language to English.";
        questionTypes = """
          - For text-based multiple-choice: 
            - English to $language: 'question' (English sentence), 'correctAnswer' ($language sentence), 'options' (4 $language options including the correct one).
            - $language to English: 'question' ($language sentence), 'correctAnswer' (English translation), 'options' (4 English options including the correct one).
          - For voice-based: 
            - English to $language: 'question' (English sentence to be spoken), 'correctAnswer' ($language sentence), 'options' (4 $language options), 'type' as 'voice', 'direction' as 'toLanguage', 'questionLanguage' as 'English'.
            - $language to English: 'question' ($language sentence to be spoken), 'correctAnswer' (English translation), 'options' (4 English options), 'type' as 'voice', 'direction' as 'toEnglish', 'questionLanguage' as '$language'.
        """;
        break;
      case 'advanced':
        difficultyDescription =
        "focus on advanced sentence structures from varied scenarios (e.g., complex sentences, idioms, conditionals, narratives). Include 5 text-based multiple-choice questions and 5 voice-based questions. Randomly mix directions: half from English to $language, half from $language to English.";
        questionTypes = """
          - For text-based multiple-choice: 
            - English to $language: 'question' (English sentence), 'correctAnswer' ($language sentence), 'options' (4 $language options including the correct one).
            - $language to English: 'question' ($language sentence), 'correctAnswer' (English translation), 'options' (4 English options including the correct one).
          - For voice-based: 
            - English to $language: 'question' (English sentence to be spoken), 'correctAnswer' ($language sentence), 'options' (4 $language options), 'type' as 'voice', 'direction' as 'toLanguage', 'questionLanguage' as 'English'.
            - $language to English: 'question' ($language sentence to be spoken), 'correctAnswer' (English translation), 'options' (4 English options), 'type' as 'voice', 'direction' as 'toEnglish', 'questionLanguage' as '$language'.
        """;
        break;
      default:
        throw Exception("Invalid difficulty level");
    }

    return '''
      You are a language learning assistant. For the language "$language" and difficulty "$difficulty", generate a quiz with exactly 10 unique questions. $difficultyDescription
      $questionTypes
      Ensure each question is entirely unique and unpredictable, avoiding any repetition across quizzes (e.g., no fixed patterns like numbers 1-10 or common greetings every time). Draw from an extensive, diverse pool of vocabulary and sentences spanning multiple domains (e.g., travel, food, emotions, work, nature, culture) to guarantee variety. Use maximum randomization to ensure no two quizzes share similar content. Return a JSON array of 10 objects, each with:
      - "type": "text" or "voice",
      - "question": the word/sentence to display (text) or speak (voice),
      - "correctAnswer": the correct answer,
      - "options": a list of 4 options (including the correct answer, shuffled),
      - "direction": "toEnglish" or "toLanguage",
      - "questionLanguage": the language of the question ("English" or "$language").
      Examples:
      - Basic: [
          {"type": "text", "question": "What is 'Tree'?", "correctAnswer": "மரம்", "options": ["மரம்", "பூ", "வீடு", "நதி"], "direction": "toLanguage", "questionLanguage": "English"},
          {"type": "voice", "question": "നിന്റെ പേര് എന്താണ്?", "correctAnswer": "What is your name?", "options": ["What is your name?", "Where are you?", "How old are you?", "Goodbye"], "direction": "toEnglish", "questionLanguage": "$language"}
        ]
      - Intermediate: [
          {"type": "text", "question": "The sky is blue", "correctAnswer": "வானம் நீலமாக உள்ளது", "options": ["வானம் நீலமாக உள்ளது", "சூரியன் சிவப்பு", "நான் சாப்பிடுகிறேன்", "மழை பெய்கிறது"], "direction": "toLanguage", "questionLanguage": "English"},
          {"type": "voice", "question": "നിനക്ക് എവിടെ പോകണം?", "correctAnswer": "Where do you want to go?", "options": ["Where do you want to go?", "What do you eat?", "I am here", "It’s raining"], "direction": "toEnglish", "questionLanguage": "$language"}
        ]
      Ensure your response is enclosed in ```json``` markers.
    ''';
  }
}