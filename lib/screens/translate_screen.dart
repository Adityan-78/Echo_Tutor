import 'dart:io';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/voice_service.dart';
import '../providers/theme_provider.dart';
import 'livetranslate_screen.dart';

class TranslateScreen extends StatefulWidget {
  @override
  _TranslateScreenState createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final VoiceService _voiceService = VoiceService();
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  final TextEditingController _textController = TextEditingController();
  List<Map<String, String>> _messages = [];
  String _sourceLang = 'Auto-Detect';
  String _targetLang = 'English';
  bool _isLoading = false;

  final List<String> _languages = [
    'Auto-Detect',
    'English',
    'Tamil',
    'Malayalam',
    'German',
    'Spanish',
    'French',
    'Hindi',
    'Telugu',
    'Kannada',
    'Bengali',
    'Marathi',
    'Gujarati',
    'Punjabi',
    'Urdu',
    'Arabic',
    'Chinese (Simplified)',
    'Japanese',
    'Korean',
    'Russian',
    'Italian',
    'Portuguese',
  ];

  @override
  void initState() {
    super.initState();
    _voiceService.initializeTts();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _isLoading = true);
      File image = File(pickedFile.path);
      await _extractAndTranslateFromImage(image);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      File audioFile = File(result.files.single.path!);
      if (audioFile.lengthSync() > 1 * 1024 * 1024) {
        _addMessage('Error: Audio file exceeds 1MB limit', '');
        return;
      }
      setState(() => _isLoading = true);
      await _transcribeAndTranslateAudio(audioFile);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _extractAndTranslateFromImage(File image) async {
    final inputImage = InputImage.fromFile(image);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
    String extracted = recognizedText.text.trim();
    print('Extracted from image: $extracted');

    if (extracted.isEmpty) {
      _addMessage('No text detected', '');
      return;
    }
    await _translateAndSpeak(extracted);
  }

  Future<void> _transcribeAndTranslateAudio(File audioFile) async {
    String base64Audio = base64Encode(await audioFile.readAsBytes());
    String transcribed = await _transcribeWithGemini(base64Audio);
    if (transcribed.isEmpty) {
      _addMessage('No speech detected in audio', '');
      return;
    }
    await _translateAndSpeak(transcribed);
  }

  Future<String> _transcribeWithGemini(String base64Audio) async {
    const apiKey = 'Enter your gemini API key here';
    const url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
    try {
      final response = await http.post(
        Uri.parse('$url?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Transcribe this audio to text:'},
                {'inlineData': {'mimeType': 'audio/mp3', 'data': base64Audio}}
              ]
            }
          ],
          'generationConfig': {'temperature': 0.5, 'maxOutputTokens': 500},
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'].trim();
      }
      print('Gemini transcription failed: ${response.body}');
      return '';
    } catch (e) {
      print('Transcription error: $e');
      return '';
    }
  }

  Future<void> _translateTextInput() async {
    String text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isLoading = true);
    await _translateAndSpeak(text);
    _textController.clear();
    setState(() => _isLoading = false);
  }

  Future<void> _translateAndSpeak(String text) async {
    String sourceCode = _sourceLang == 'Auto-Detect' ? 'auto' : _sourceLang;
    String targetCode = _targetLang;
    String detectedLang = _sourceLang;

    String cleanedText = text.replaceAll(RegExp(r'(P\.{2,}|p\.{2,})\s*', caseSensitive: false), '').trim();
    if (cleanedText.isEmpty) {
      _addMessage(text, 'No meaningful text to translate');
      return;
    }

    String translated = await _translateWithGemini(cleanedText, sourceCode, targetCode);
    if (translated.isEmpty || translated.contains('not possible')) {
      _addMessage(cleanedText, 'Translation failed - invalid input or language mismatch');
      return;
    }

    if (sourceCode == 'auto') {
      detectedLang = _guessLanguage(cleanedText);
    }

    _addMessage(cleanedText, translated);

    await _voiceService.speak(cleanedText, detectedLang);
    await Future.delayed(const Duration(seconds: 3));
    await _voiceService.speak(translated, targetCode);
  }

  Future<String> _translateWithGemini(String text, String source, String target) async {
    const apiKey = 'AIzaSyDu-yb8Ov6KalrCmMjxglC0Wiw6N0AOUrw';
    const url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
    try {
      final response = await http.post(
        Uri.parse('$url?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': source == 'auto'
                      ? 'Detect the language of "$text" and translate it to $target. If the text is not translatable or contains no meaningful content, return "Translation not possible". Otherwise, return only the translated text.'
                      : 'Translate "$text" from $source to $target. If the text is not translatable or contains no meaningful content, return "Translation not possible". Otherwise, return only the translated text.'
                }
              ]
            }
          ],
          'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 500},
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String result = data['candidates'][0]['content']['parts'][0]['text'].trim();
        print('Gemini translated "$text" to "$result"');
        return result;
      }
      print('Gemini translation failed: ${response.body}');
      return '';
    } catch (e) {
      print('Translation error: $e');
      return '';
    }
  }

  String _guessLanguage(String text) {
    if (text.contains(RegExp(r'[ാ-ൿ]'))) return 'Malayalam';
    if (text.contains(RegExp(r'[ஂ-௿]'))) return 'Tamil';
    if (text.contains(RegExp(r'[ँ-৿]'))) return 'Hindi';
    return 'English';
  }

  void _addMessage(String original, String translated) {
    setState(() {
      _messages.add({'user': original, 'bot': translated});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDarkMode
                      ? [
                    const Color(0xFF1E1E1E),
                    const Color(0xFF121212),
                  ]
                      : [
                    const Color(0xFFE3F2FD),
                    const Color(0xFFBBDEFB),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.01),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                          size: size.width * 0.06,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        "Translate",
                        style: GoogleFonts.poppins(
                          fontSize: size.width * 0.045,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      SizedBox(width: size.width * 0.12),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.01),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: size.width * 0.03, vertical: size.height * 0.005),
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                            borderRadius: BorderRadius.circular(size.width * 0.03),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: size.width * 0.02,
                                offset: Offset(0, size.height * 0.002),
                              ),
                            ],
                          ),
                          child: DropdownButton<String>(
                            value: _sourceLang,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: _languages
                                .map((lang) => DropdownMenuItem(
                              value: lang,
                              child: Text(
                                lang,
                                style: GoogleFonts.poppins(
                                  color: isDarkMode ? Colors.white70 : Colors.black87,
                                  fontSize: size.width * 0.035,
                                ),
                              ),
                            ))
                                .toList(),
                            onChanged: (value) => setState(() => _sourceLang = value!),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: isDarkMode ? Colors.white54 : Colors.grey[600],
                              size: size.width * 0.05,
                            ),
                          ),
                        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),
                      ),
                      SizedBox(width: size.width * 0.04),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: size.width * 0.03, vertical: size.height * 0.005),
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                            borderRadius: BorderRadius.circular(size.width * 0.03),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: size.width * 0.02,
                                offset: Offset(0, size.height * 0.002),
                              ),
                            ],
                          ),
                          child: DropdownButton<String>(
                            value: _targetLang,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: _languages
                                .where((lang) => lang != 'Auto-Detect')
                                .map((lang) => DropdownMenuItem(
                              value: lang,
                              child: Text(
                                lang,
                                style: GoogleFonts.poppins(
                                  color: isDarkMode ? Colors.white70 : Colors.black87,
                                  fontSize: size.width * 0.035,
                                ),
                              ),
                            ))
                                .toList(),
                            onChanged: (value) => setState(() => _targetLang = value!),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: isDarkMode ? Colors.white54 : Colors.grey[600],
                              size: size.width * 0.05,
                            ),
                          ),
                        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: size.height * 0.01),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () => _voiceService.speak(
                                message['user']!,
                                _sourceLang == 'Auto-Detect'
                                    ? _guessLanguage(message['user']!)
                                    : _sourceLang),
                            child: Container(
                              margin: EdgeInsets.symmetric(vertical: size.height * 0.005, horizontal: size.width * 0.04),
                              padding: EdgeInsets.all(size.width * 0.03),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3),
                                borderRadius: BorderRadius.circular(size.width * 0.04),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: size.width * 0.02,
                                    offset: Offset(0, size.height * 0.002),
                                  ),
                                ],
                              ),
                              child: Text(
                                message['user']!,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: size.width * 0.035,
                                ),
                              ),
                            ),
                          ).animate().fadeIn(
                            duration: 600.ms,
                            delay: (index * 100).ms,
                          ).slideX(
                            begin: 0.3,
                            duration: 600.ms,
                            curve: Curves.easeOut,
                          ),
                          GestureDetector(
                            onTap: () => _voiceService.speak(message['bot']!, _targetLang),
                            child: Container(
                              margin: EdgeInsets.symmetric(vertical: size.height * 0.005, horizontal: size.width * 0.04),
                              padding: EdgeInsets.all(size.width * 0.03),
                              alignment: Alignment.centerLeft,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(size.width * 0.04),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: size.width * 0.02,
                                    offset: Offset(0, size.height * 0.002),
                                  ),
                                ],
                              ),
                              child: Text(
                                message['bot']!,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: size.width * 0.035,
                                ),
                              ),
                            ),
                          ).animate().fadeIn(
                            duration: 600.ms,
                            delay: (index * 100 + 50).ms,
                          ).slideX(
                            begin: -0.3,
                            duration: 600.ms,
                            curve: Curves.easeOut,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (_isLoading)
                  Padding(
                    padding: EdgeInsets.all(size.width * 0.02),
                    child: CircularProgressIndicator(
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF2196F3)),
                    ).animate().scale(duration: 300.ms),
                  ),
                Padding(
                  padding: EdgeInsets.all(size.width * 0.04),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                                borderRadius: BorderRadius.circular(size.width * 0.03),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: size.width * 0.02,
                                    offset: Offset(0, size.height * 0.002),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _textController,
                                style: GoogleFonts.poppins(
                                  color: isDarkMode ? Colors.white70 : Colors.black87,
                                  fontSize: size.width * 0.035,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter text to translate',
                                  hintStyle: GoogleFonts.poppins(
                                    color: isDarkMode ? Colors.white54 : Colors.grey[400],
                                    fontSize: size.width * 0.035,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(size.width * 0.03),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: size.width * 0.04, vertical: size.height * 0.015),
                                ),
                                onSubmitted: (_) => _translateTextInput(),
                              ),
                            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),
                          ),
                          SizedBox(width: size.width * 0.02),
                          IconButton(
                            icon: Icon(Icons.send, color: const Color(0xFF2196F3), size: size.width * 0.06),
                            onPressed: _translateTextInput,
                            style: IconButton.styleFrom(
                              backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(size.width * 0.03),
                                side: const BorderSide(
                                  color: Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                            ),
                          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),
                        ],
                      ),
                      SizedBox(height: size.height * 0.02),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            icon: Icons.image,
                            label: 'Image',
                            onPressed: _pickImage,
                            size: size,
                          ),
                          _buildActionButton(
                            icon: Icons.audiotrack,
                            label: 'Audio',
                            onPressed: _pickAudio,
                            size: size,
                          ),
                          _buildActionButton(
                            icon: Icons.videocam,
                            label: 'Live',
                            onPressed: () async {
                              final cameras = await availableCameras();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LiveTranslateScreen(cameras, _targetLang),
                                ),
                              );
                            },
                            size: size,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Size size,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        foregroundColor: const Color(0xFF2196F3),
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.015),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(size.width * 0.03),
          side: const BorderSide(
            color: Color(0xFF2196F3),
            width: 2,
          ),
        ),
        elevation: 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: size.width * 0.05),
          SizedBox(width: size.width * 0.02),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: const Color(0xFF2196F3),
              fontWeight: FontWeight.w500,
              fontSize: size.width * 0.035,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(
      begin: 0.2,
      duration: 600.ms,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _voiceService.stop();
    _textController.dispose();
    super.dispose();
  }
}