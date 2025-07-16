import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/voice_service.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class LiveTranslateScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String targetLang;

  LiveTranslateScreen(this.cameras, this.targetLang);

  @override
  _LiveTranslateScreenState createState() => _LiveTranslateScreenState();
}

class _LiveTranslateScreenState extends State<LiveTranslateScreen> {
  late CameraController _controller;
  final TextRecognizer _textRecognizer = TextRecognizer();
  final VoiceService _voiceService = VoiceService();
  String _extractedText = '';
  String _translatedText = '';
  bool _isProcessing = false;
  String _lastProcessedText = '';
  bool _isLiveMode = true;

  @override
  void initState() {
    super.initState();
    _voiceService.initializeTts();
    _controller = CameraController(widget.cameras[0], ResolutionPreset.high);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      if (_isLiveMode) _processFramePeriodically();
    }).catchError((e) {
      print('Camera initialization error: $e');
    });
  }

  Future<void> _processFramePeriodically() async {
    while (mounted && _isLiveMode) {
      if (!_isProcessing) {
        await _captureAndProcessFrame(isLive: true);
      }
      await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  Future<void> _captureAndProcessFrame({required bool isLive}) async {
    if (_isProcessing || !_controller.value.isInitialized) return;
    setState(() => _isProcessing = true);

    try {
      final XFile imageFile = await _controller.takePicture();
      final InputImage inputImage = InputImage.fromFilePath(imageFile.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      String extracted = recognizedText.text.trim();

      if (extracted.isEmpty || (isLive && extracted == _lastProcessedText)) {
        if (!isLive) setState(() => _extractedText = 'No text detected');
      } else {
        String cleanedText = extracted.replaceAll(RegExp(r'(P\.{2,}|p\.{2,})\s*', caseSensitive: false), '').trim();
        if (cleanedText.isEmpty) {
          if (!isLive) setState(() => _extractedText = 'No text detected');
        } else {
          String translated = await _translateWithGemini(cleanedText, 'auto', widget.targetLang);
          if (translated.isNotEmpty && !translated.contains('not possible')) {
            setState(() {
              _extractedText = cleanedText;
              _translatedText = translated;
              _lastProcessedText = cleanedText;
            });
            await _voiceService.speak(translated, widget.targetLang);
          } else if (!isLive) {
            setState(() => _translatedText = 'Translation failed');
          }
        }
      }
    } catch (e) {
      print('Frame processing error: $e');
      if (!isLive) setState(() => _translatedText = 'Error processing frame');
    } finally {
      setState(() => _isProcessing = false);
    }
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
        return data['candidates'][0]['content']['parts'][0]['text'].trim();
      }
      print('Gemini translation failed: ${response.body}');
      return '';
    } catch (e) {
      print('Translation error: $e');
      return '';
    }
  }

  void _toggleMode() {
    setState(() {
      _isLiveMode = !_isLiveMode;
      _extractedText = '';
      _translatedText = '';
      _lastProcessedText = '';
      if (_isLiveMode) _processFramePeriodically();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (!_controller.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Live Translate', style: GoogleFonts.poppins(fontSize: size.width * 0.045)),
          backgroundColor: Colors.white,
          elevation: 2,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Translate', style: GoogleFonts.poppins(fontSize: size.width * 0.045)),
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: size.width * 0.05),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CameraPreview(_controller),
          ),
          Positioned(
            bottom: size.height * 0.1,
            left: size.width * 0.05,
            right: size.width * 0.05,
            child: Container(
              padding: EdgeInsets.all(size.width * 0.02),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(size.width * 0.03),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: size.width * 0.02,
                    offset: Offset(0, size.height * 0.005),
                  ),
                ],
              ),
              constraints: BoxConstraints(maxHeight: size.height * 0.2),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original: $_extractedText',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: size.width * 0.035,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: size.height * 0.01),
                    Text(
                      'Translated: $_translatedText',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: size.width * 0.035,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.02,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                    if (_isLiveMode) _toggleMode();
                    _captureAndProcessFrame(isLive: false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2196F3),
                    padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.015),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.width * 0.03)),
                    elevation: 2,
                  ),
                  child: Text(
                    _isLiveMode ? 'Capture' : 'Translate',
                    style: GoogleFonts.poppins(fontSize: size.width * 0.035),
                  ),
                ),
                SizedBox(width: size.width * 0.04),
                ElevatedButton(
                  onPressed: _toggleMode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2196F3),
                    padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.015),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.width * 0.03)),
                    elevation: 2,
                  ),
                  child: Text(
                    _isLiveMode ? 'Stop Live' : 'Start Live',
                    style: GoogleFonts.poppins(fontSize: size.width * 0.035),
                  ),
                ),
              ],
            ),
          ),
          if (_isProcessing)
            Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: size.width * 0.01,
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _textRecognizer.close();
    _voiceService.stop();
    super.dispose();
  }
}