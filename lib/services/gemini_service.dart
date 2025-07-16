import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  // Replace with your actual Gemini API key
  static const String _apiKey = 'Enter your gemini API key';
  // Using a hypothetical endpoint; update based on Google's official Gemini API docs
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  Future<String> getChatResponse(String message, String language) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _apiKey, // Gemini API uses this header for auth
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': 'You are a friendly and educative language tutor. You should be fun to talk to. You can make fun of the user ig he makes a mistake in a friendly and not offensive way and then correct him. Respond to this message in $language or provide a helpful explanation related to learning. Do not elaborate things too much and make it boring for the user. Avoid using emoji in the response. keep things crisp and on point for the question that user asks $language: "$message"'
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7, // Controls creativity; adjust as needed
            'maxOutputTokens': 200, // Limits response length
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Extract the generated text from the response
        return data['candidates'][0]['content']['parts'][0]['text'] ?? 'Sorry, I couldn’t generate a response.';
      } else {
        return 'Error: Unable to get a response from the server (${response.statusCode}).';
      }
    } catch (e) {
      return 'Oops! Something went wrong: $e';
    }
  }
}