import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class GeminiServicePronounce {
  static const String _apiKey = 'Enter your gemini API key';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
  static Database? _database;

  // Initialize SQLite database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'word_history.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT NOT NULL,
            language TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // Insert a word with timestamp
  Future<void> _insertWord(String word, String language) async {
    final db = await database;
    await db.insert(
      'words',
      {
        'word': word,
        'language': language,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('Inserted into DB: $word ($language)');
  }

  // Get words used in the last 24 hours for a language
  Future<Set<String>> _getRecentWords(String language) async {
    final db = await database;
    final int cutoff = DateTime.now().subtract(Duration(hours: 24)).millisecondsSinceEpoch;
    final List<Map<String, dynamic>> result = await db.query(
      'words',
      where: 'language = ? AND timestamp > ?',
      whereArgs: [language, cutoff],
    );
    return result.map((row) => row['word'] as String).toSet();
  }

  // Clean up words older than 24 hours
  Future<void> _cleanOldWords() async {
    final db = await database;
    final int cutoff = DateTime.now().subtract(Duration(hours: 24)).millisecondsSinceEpoch;
    await db.delete(
      'words',
      where: 'timestamp <= ?',
      whereArgs: [cutoff],
    );
    print('Cleaned old words before $cutoff');
  }

  Future<Map<String, String>> fetchWord(String language, Set<String> usedWords) async {
    await _cleanOldWords(); // Clear out expired words
    final recentWords = await _getRecentWords(language); // Get words from last 24h
    final allUsedWords = usedWords.union(recentWords); // Combine session + DB words

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': '''
                    Generate a unique amateur level word in "$language" not in this list: ${allUsedWords.join(', ')} (or empty if none used yet):
                    - "text": the word in "$language" (e.g., "agua" for Spanish).
                    - "phonetic": English phonetic spelling (e.g., "/ˈa.ɡwa/" for Spanish).
                    - "meaning": English meaning (e.g., "water" for Spanish).
                    Return JSON: {"text": "word", "phonetic": "/phonetic/", "meaning": "meaning"} wrapped in ```json```.
                    Ensure variety, native accuracy, and maximize randomness for uniqueness.
                  '''
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 1.2,
            'maxOutputTokens': 100,
            'topP': 0.95,
          },
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String result = data['candidates'][0]['content']['parts'][0]['text']
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final wordData = jsonDecode(result) as Map<String, dynamic>;
        final word = {
          'text': wordData['text']?.toString() ?? '',
          'phonetic': wordData['phonetic']?.toString() ?? '',
          'meaning': wordData['meaning']?.toString() ?? 'Unknown',
        };
        print('Gemini fetched: ${word['text']} - ${word['meaning']}');
        if (word['text']!.isEmpty || allUsedWords.contains(word['text'])) {
          print('Duplicate or empty: ${word['text']}, retrying...');
          return await fetchWord(language, usedWords);
        }
        await _insertWord(word['text']!, language); // Store in DB
        return word;
      }
      print('Fetch failed: ${response.statusCode} - ${response.body}');
      throw Exception('API failed');
    } catch (e) {
      print('Fetch error: $e');
      throw Exception('Word fetch failed');
    }
  }

  Future<Map<String, String>> analyzePronunciation(String transcribed, String correctWord, String language) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': '''
                    Analyze pronunciation in "$language":
                    - User said: "$transcribed".
                    - Target: "$correctWord".
                    Return JSON: {"corrected": "word", "feedback": "tip (max 20 words)", "phonetic": "/phonetic/"} in ```json```.
                  '''
                }
              ]
            }
          ],
          'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 150},
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String result = data['candidates'][0]['content']['parts'][0]['text']
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final feedback = jsonDecode(result) as Map<String, dynamic>;
        return {
          'corrected': feedback['corrected']?.toString() ?? correctWord,
          'feedback': feedback['feedback']?.toString() ?? 'Good effort!',
          'phonetic': feedback['phonetic']?.toString() ?? '',
        };
      }
      print('Analysis failed: ${response.body}');
      return {
        'corrected': correctWord,
        'feedback': 'Analysis unavailable',
        'phonetic': '',
      };
    } catch (e) {
      print('Analysis error: $e');
      return {
        'corrected': correctWord,
        'feedback': 'Error in analysis',
        'phonetic': '',
      };
    }
  }
}