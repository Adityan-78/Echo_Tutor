import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiAchievementGenerator {
  static const String _apiKey = "Enter your gemini API key"; // Replace with your actual API key
  static const String _endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent";

  // Generate daily achievements based on the selected language
  Future<List<Map<String, dynamic>>> generateDailyAchievements(String selectedLanguage) async {
    try {
      final response = await http.post(
        Uri.parse("$_endpoint?key=$_apiKey"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text": "Generate exactly 3 daily achievements for a language learning app called Echo, specifically for learning $selectedLanguage. Each achievement must include: a title (short and catchy), a description (1 sentence), and an associated action (one of: 'complete a lesson', 'practice pronunciation', 'take a quiz'). Format the response as a JSON array of objects with keys 'title', 'description', and 'action'."
                }
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.7,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 150,
            "response_mime_type": "application/json",
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final achievementsText = data['candidates'][0]['content']['parts'][0]['text'] as String;
        final achievements = jsonDecode(achievementsText) as List<dynamic>;

        if (achievements.length != 3) {
          print("❌ Gemini API returned ${achievements.length} daily achievements instead of 3");
          return _generateDailyAchievementsFallback(selectedLanguage);
        }

        return achievements.map((achievement) {
          return {
            "title": achievement["title"],
            "description": achievement["description"],
            "action": _normalizeAction(achievement["action"]),
            "completed": false,
          };
        }).toList();
      } else {
        print("❌ Failed to fetch daily achievements: ${response.statusCode} - ${response.body}");
        return _generateDailyAchievementsFallback(selectedLanguage);
      }
    } catch (e) {
      print("❌ Error fetching daily achievements: $e");
      return _generateDailyAchievementsFallback(selectedLanguage);
    }
  }

  // Generate overall achievements for all languages
  Future<List<Map<String, dynamic>>> generateOverallAchievements() async {
    try {
      final response = await http.post(
        Uri.parse("$_endpoint?key=$_apiKey"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text": "Generate exactly 5 overall achievements for a language learning app called Echo, applicable to all languages (e.g., English, Spanish, Hindi, etc.). Each achievement must include: a title (short and catchy), a description (1 sentence), and an associated action (one of: 'complete lessons', 'maintain a streak', 'translate sentences', 'practice pronunciation', 'take quizzes', or null if no action applies). Format the response as a JSON array of objects with keys 'title', 'description', and 'action'."
                }
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.7,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 200,
            "response_mime_type": "application/json",
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final achievementsText = data['candidates'][0]['content']['parts'][0]['text'] as String;
        final achievements = jsonDecode(achievementsText) as List<dynamic>;

        if (achievements.length != 5) {
          print("❌ Gemini API returned ${achievements.length} overall achievements instead of 5");
          return _generateOverallAchievementsFallback();
        }

        return achievements.map((achievement) {
          return {
            "title": achievement["title"],
            "description": achievement["description"],
            "action": _normalizeAction(achievement["action"]),
            "language": "Any", // Used for navigation (can be any language)
            "completed": false,
          };
        }).toList();
      } else {
        print("❌ Failed to fetch overall achievements: ${response.statusCode} - ${response.body}");
        return _generateOverallAchievementsFallback();
      }
    } catch (e) {
      print("❌ Error fetching overall achievements: $e");
      return _generateOverallAchievementsFallback();
    }
  }

  // Normalize the action string to match our app's expected actions
  String? _normalizeAction(String? action) {
    if (action == null) return null;
    final lowerAction = action.toLowerCase();
    if (lowerAction.contains("lesson")) return "lesson";
    if (lowerAction.contains("pronunciation")) return "pronunciation";
    if (lowerAction.contains("quiz")) return "quiz";
    if (lowerAction.contains("translate")) return "translate";
    if (lowerAction.contains("streak")) return null; // Streak achievements don't have an action
    return null; // Default to no action if unrecognized
  }

  // Fallback for daily achievements if API fails
  List<Map<String, dynamic>> _generateDailyAchievementsFallback(String selectedLanguage) {
    return [
      {
        "title": "Daily $selectedLanguage Lesson",
        "description": "Complete one $selectedLanguage lesson today.",
        "action": "lesson",
        "completed": false,
      },
      {
        "title": "Speak $selectedLanguage",
        "description": "Practice $selectedLanguage pronunciation for 5 minutes.",
        "action": "pronunciation",
        "completed": false,
      },
      {
        "title": "$selectedLanguage Quiz Time",
        "description": "Take a short $selectedLanguage quiz to test your skills.",
        "action": "quiz",
        "completed": false,
      },
    ];
  }

  // Fallback for overall achievements if API fails
  List<Map<String, dynamic>> _generateOverallAchievementsFallback() {
    return [
      {
        "title": "Polyglot Beginner",
        "description": "Complete 5 lessons in any language.",
        "action": "lesson",
        "language": "Any",
        "completed": false,
      },
      {
        "title": "Streak Master",
        "description": "Maintain a 7-day streak across any language.",
        "action": null,
        "language": "Any",
        "completed": false,
      },
      {
        "title": "Translation Pro",
        "description": "Translate 10 sentences in any language.",
        "action": "translate",
        "language": "Any",
        "completed": false,
      },
      {
        "title": "Quiz Whiz",
        "description": "Complete 3 quizzes with a score above 80% in any language.",
        "action": "quiz",
        "language": "Any",
        "completed": false,
      },
      {
        "title": "Pronunciation Star",
        "description": "Practice pronunciation 10 times in any language.",
        "action": "pronunciation",
        "language": "Any",
        "completed": false,
      },
    ];
  }
}