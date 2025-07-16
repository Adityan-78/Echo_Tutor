import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService1 {
  static const String _apiKey = 'Enter your gemini API key'; // Replace with your actual API key
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  Future<Map<String, dynamic>> getLessonContent(
      String language,
      String level,
      String stage,
      String userInput,
      List<String> previousWords,
      ) async {
    try {
      final prompt = _buildPrompt(language, level, stage, userInput, previousWords);
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 500},
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
          print('Parsed API Data: $result');
          return _normalizeData(result, stage, language, userInput);
        }
      }
      return _getMockData(language, level, stage, userInput);
    } catch (e) {
      print('Exception: $e');
      return _getMockData(language, level, stage, userInput);
    }
  }

  Map<String, dynamic> _normalizeData(Map<String, dynamic> data, String stage, String language, String userInput) {
    final key = stage == 'vocabulary' ? 'vocabulary' : stage == 'sentences' ? 'sentences' : 'grammar';
    final content = data[key] as Map<String, dynamic>? ?? {};
    final assessment = (data['assessment'] as List<dynamic>?)?.map((q) => q as Map<String, dynamic>).toList() ?? [];

    // Normalize content
    final defaultContent = {
      'vocabulary': {
        'word': userInput,
        'translation': userInput,
        'pronunciation': '/unknown/',
        'english_pronunciation': 'unknown',
        'examples': ['$userInput example 1', '$userInput example 2'],
      },
      'sentences': {
        'structure': 'Unknown',
        'example': userInput,
        'translation': userInput,
      },
      'grammar': {
        'rule': 'Unknown rule',
        'explanation': 'No explanation available',
        'examples': ['$userInput example 1', '$userInput example 2'],
      },
    };
    final normalizedContent = Map<String, dynamic>.from(defaultContent[stage]!)..addAll(content);

    // Normalize assessment: Ensure 'answer' is a String
    for (var q in assessment) {
      q['type'] ??= 'pick';
      q['question'] ??= 'Default question for $userInput in $language';
      final answerValue = q['answer'];
      q['answer'] = answerValue is String
          ? answerValue
          : answerValue is Map
          ? (answerValue['word'] as String? ?? answerValue['example'] as String? ?? normalizedContent[stage == 'vocabulary' ? 'word' : stage == 'sentences' ? 'example' : 'examples'][0])
          : normalizedContent[stage == 'vocabulary' ? 'word' : stage == 'sentences' ? 'example' : 'examples'][0];
      q['options'] ??= [q['answer'], 'Other'];
      print('Normalized question: $q');
    }

    return {
      key: normalizedContent,
      'assessment': assessment.isEmpty ? _defaultAssessment(normalizedContent, stage, language, userInput) : assessment,
    };
  }

  List<Map<String, dynamic>> _defaultAssessment(Map<String, dynamic> content, String stage, String language, String userInput) {
    final answer = stage == 'vocabulary'
        ? content['word'] as String
        : stage == 'sentences'
        ? content['example'] as String
        : content['examples'][0] as String;
    return [
      {
        'type': 'match',
        'question': 'Match "$userInput" to its $language translation:',
        'options': [answer, 'Wrong Option'],
        'answer': answer,
      },
      {
        'type': 'fill',
        'question': 'Fill in: ___ means "$userInput" in $language.',
        'options': [answer, 'Incorrect'],
        'answer': answer,
      },
      {
        'type': 'pick',
        'question': 'Which is the $language word for "$userInput"?',
        'options': [answer, 'Other'],
        'answer': answer,
      },
    ];
  }

  String _buildPrompt(String language, String level, String stage, String userInput, List<String> previousWords) {
    return '''
      You are a $language tutor for a $level learner. Stage: $stage. User input: "$userInput".
      ${previousWords.isNotEmpty ? 'Incorporate these previous words where relevant: ${previousWords.join(', ')}.' : ''}

      ${stage == 'vocabulary' ? '''
        The user has provided an English word: "$userInput". 
        Provide:
        - "word": the accurate translation of "$userInput" into $language (use native script, e.g., "ありがとう" for Japanese)
        - "translation": the English word "$userInput"
        - "pronunciation": IPA notation for the $language word
        - "english_pronunciation": a simple English transliteration (e.g., "Arigatō" for "ありがとう")
        - "examples": 2 example sentences in $language using the translated word
        Include "assessment": 3 questions (match, fill-in, pick) based on this translated word, each with "answer" as a string (e.g., "Hola"), not an object.
      ''' : stage == 'sentences' ? '''
        The user has provided an English sentence: "$userInput".
        Provide only:
        - "structure": the basic grammatical structure (e.g., "Subject + Verb")
        - "example": the accurate direct translation of "$userInput" into $language
        - "translation": the English sentence "$userInput"
        Include "assessment": 3 questions (match, fill-in, pick) based on this translated sentence, each with "answer" as a string, not an object.
      ''' : '''
        The user has provided an English sentence or concept: "$userInput".
        Provide:
        - "rule": a relevant grammar rule in $language related to "$userInput"
        - "explanation": a brief explanation of the rule
        - "examples": 2 example sentences in $language demonstrating the rule
        Include "assessment": 3 questions (match, fill-in, pick) based on this rule, each with "answer" as a string, not an object.
      '''}

      Return JSON in ```json``` markers with "${stage == 'vocabulary' ? 'vocabulary' : stage == 'sentences' ? 'sentences' : 'grammar'}" (as a single object), "assessment".
      Ensure "answer" in each assessment question is a string, not a nested object.
    ''';
  }

  Map<String, dynamic> _getMockData(String language, String level, String stage, String userInput) {
    final Map<String, Map<String, Map<String, String>>> translations = {
      'hello': {
        'Spanish': {'word': 'Hola', 'english_pronunciation': 'OH-lah', 'ipa': '/ˈo.la/'},
        'French': {'word': 'Salut', 'english_pronunciation': 'sah-LOO', 'ipa': '/sa.ly/'},
        'German': {'word': 'Hallo', 'english_pronunciation': 'HAH-loh', 'ipa': '/ˈha.lo/'},
        'Italian': {'word': 'Ciao', 'english_pronunciation': 'CHOW', 'ipa': '/ˈtʃa.o/'},
        'Portuguese': {'word': 'Olá', 'english_pronunciation': 'oh-LAH', 'ipa': '/oˈla/'},
        'Hindi': {'word': 'नमस्ते', 'english_pronunciation': 'nuh-MUS-tay', 'ipa': '/nəˈməs.teɪ/'},
        'Japanese': {'word': 'こんにちは', 'english_pronunciation': 'kon-NEE-chee-wah', 'ipa': '/kon.ni.tɕi.wa/'},
        'Korean': {'word': '안녕하세요', 'english_pronunciation': 'ahn-YOUNG-ha-seh-yo', 'ipa': '/an.njʌŋ.ha.se.jo/'},
        'Chinese': {'word': '你好', 'english_pronunciation': 'nee HOW', 'ipa': '/ni˧˩ xɑʊ˩˧/'},
        'Arabic': {'word': 'مرحبا', 'english_pronunciation': 'mar-HA-ban', 'ipa': '/mar.ħa.ban/'},
        'Russian': {'word': 'Привет', 'english_pronunciation': 'pree-VYET', 'ipa': '/priˈvʲet/'},
        'English': {'word': 'Hello', 'english_pronunciation': 'HEL-oh', 'ipa': '/hɛˈloʊ/'},
      },
      'thank you': {
        'Spanish': {'word': 'Gracias', 'english_pronunciation': 'GRAH-see-ahs', 'ipa': '/ˈɡɾa.θjas/'},
        'French': {'word': 'Merci', 'english_pronunciation': 'MEHR-see', 'ipa': '/mɛʁ.si/'},
        'German': {'word': 'Danke', 'english_pronunciation': 'DAHN-keh', 'ipa': '/ˈdaŋ.kə/'},
        'Italian': {'word': 'Grazie', 'english_pronunciation': 'GRAHT-see-eh', 'ipa': '/ˈɡrat.tsje/'},
        'Portuguese': {'word': 'Obrigado', 'english_pronunciation': 'oh-bree-GAH-doo', 'ipa': '/o.bɾiˈɡa.du/'},
        'Hindi': {'word': 'धन्यवाद', 'english_pronunciation': 'DHUN-yuh-vaad', 'ipa': '/ˈd̪ʱən.jə.vaːd̪/'},
        'Japanese': {'word': 'ありがとう', 'english_pronunciation': 'ah-ree-GAH-toh', 'ipa': '/a.ɾi.ɡaˈtoː/'},
        'Korean': {'word': '감사합니다', 'english_pronunciation': 'gam-SAH-ham-nee-da', 'ipa': '/kam.sa.ham.ni.da/'},
        'Chinese': {'word': '谢谢', 'english_pronunciation': 'shieh-SHIEH', 'ipa': '/ɕjɛ˥˩ ɕjɛ˥˩/'},
        'Arabic': {'word': 'شكرا', 'english_pronunciation': 'SHOOK-rahn', 'ipa': '/ˈʃuk.ran/'},
        'Russian': {'word': 'Спасибо', 'english_pronunciation': 'spah-SEE-boh', 'ipa': '/spɐˈsʲi.bə/'},
        'English': {'word': 'Thank you', 'english_pronunciation': 'THANK yoo', 'ipa': '/θæŋk juː/'},
      },
    };

    if (stage == 'vocabulary') {
      final inputLower = userInput.toLowerCase();
      final translationData = translations[inputLower]?[language] ??
          {
            'word': '$userInput-$language', // Fallback
            'english_pronunciation': 'unknown',
            'ipa': '/unknown/',
          };
      final translatedWord = translationData['word']!;
      final englishPronun = translationData['english_pronunciation']!;
      final ipaPronun = translationData['ipa']!;
      final content = {
        'word': translatedWord,
        'translation': userInput,
        'pronunciation': ipaPronun,
        'english_pronunciation': englishPronun,
        'examples': [
          '$translatedWord, hello!',
          '$translatedWord again!',
        ],
      };
      return _normalizeData({
        'vocabulary': content,
        'assessment': [
          {
            'type': 'match',
            'question': 'Match "$userInput" to its $language translation:',
            'options': [translatedWord, 'Wrong Option'],
            'answer': translatedWord,
          },
          {
            'type': 'fill',
            'question': 'Fill in: ___ means "$userInput" in $language.',
            'options': [translatedWord, 'Incorrect'],
            'answer': translatedWord,
          },
          {
            'type': 'pick',
            'question': 'Which is the $language word for "$userInput"?',
            'options': [translatedWord, 'Other'],
            'answer': translatedWord,
          },
        ],
      }, stage, language, userInput);
    } else if (stage == 'sentences') {
      final translatedSentence = '$userInput in $language';
      final content = {
        'structure': 'Subject + Verb',
        'example': translatedSentence,
        'translation': userInput,
      };
      return _normalizeData({
        'sentences': content,
        'assessment': [
          {
            'type': 'fill',
            'question': 'Fill in: ___ is "$userInput" in $language.',
            'options': [translatedSentence, 'Wrong'],
            'answer': translatedSentence,
          },
          {
            'type': 'match',
            'question': 'Match "$userInput" to its $language translation:',
            'options': [translatedSentence, 'Incorrect'],
            'answer': translatedSentence,
          },
          {
            'type': 'pick',
            'question': 'Which is "$userInput" in $language?',
            'options': [translatedSentence, 'Other'],
            'answer': translatedSentence,
          },
        ],
      }, stage, language, userInput);
    } else {
      final ruleExample = 'Example in $language';
      final content = {
        'rule': 'Verb conjugation',
        'explanation': 'Verbs change based on subject in $language.',
        'examples': [ruleExample, 'Another example'],
      };
      return _normalizeData({
        'grammar': content,
        'assessment': [
          {
            'type': 'pick',
            'question': 'Correct form for "I eat" in $language?',
            'options': [ruleExample, 'Wrong'],
            'answer': ruleExample,
          },
        ],
      }, stage, language, userInput);
    }
  }
}