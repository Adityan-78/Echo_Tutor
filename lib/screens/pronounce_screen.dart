import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/gemini_service_pronounce.dart';
import '../services/voice_service2.dart';
import '../providers/theme_provider.dart';

class PronounceScreen extends StatefulWidget {
  final String selectedLanguage;
  const PronounceScreen({required this.selectedLanguage, Key? key}) : super(key: key);

  @override
  _PronounceScreenState createState() => _PronounceScreenState();
}

class _PronounceScreenState extends State<PronounceScreen> with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late ConfettiController _confettiController;
  late GeminiServicePronounce _geminiService;
  late VoiceService2 _voiceService;
  String _currentWord = '';
  String _currentMeaning = '';
  String _transcribedText = '';
  String _correctedText = '';
  String _pronunciationFeedback = '';
  String _phoneticCorrect = '';
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _showLoading = false;
  bool _isPronunciationWrong = false;
  int _attemptCount = 0;
  int _totalWords = 0;
  int _xpPoints = 0;
  String _errorMessage = '';
  double _soundLevel = 0.0;
  final Set<String> _usedWords = {};
  Map<String, String>? _nextWord;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _geminiService = GeminiServicePronounce();
    _voiceService = VoiceService2();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _initSpeech();
    _checkPermissions();
    _loadNextWord();
  }

  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Speech error: ${error.errorMsg}';
            _isRecording = false;
          });
        }
      },
    );
    if (mounted) {
      setState(() => _errorMessage = available ? '' : 'Speech init failed');
    }
  }

  Future<void> _checkPermissions() async {
    if (!await Permission.microphone.request().isGranted && mounted) {
      setState(() => _errorMessage = 'Microphone permission denied');
    }
  }

  Future<void> _loadNextWord() async {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _currentWord = '';
      _currentMeaning = '';
      _transcribedText = '';
      _correctedText = '';
      _pronunciationFeedback = '';
      _isPronunciationWrong = false;
    });
    _animationController.reset();

    try {
      Map<String, String> wordData = _nextWord ?? await _geminiService.fetchWord(widget.selectedLanguage, _usedWords);
      _nextWord = null;

      if (mounted) {
        setState(() {
          _currentWord = wordData['text']!;
          _phoneticCorrect = wordData['phonetic']!;
          _currentMeaning = wordData['meaning']!;
          _usedWords.add(_currentWord);
          _attemptCount = 0;
          _errorMessage = '';
          _isProcessing = false;
        });
        _animationController.forward();
        await _voiceService.speak(_currentWord, widget.selectedLanguage);
        print('Loaded: $_currentWord - $_currentMeaning, Used: ${_usedWords.length}');
        _preloadNextWord();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load word: $e';
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _preloadNextWord() async {
    if (!mounted) return;
    try {
      _nextWord = await _geminiService.fetchWord(widget.selectedLanguage, _usedWords);
      print('Preloaded: ${_nextWord!['text']} - ${_nextWord!['meaning']}');
    } catch (e) {
      print('Preload error: $e');
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isProcessing || !await Permission.microphone.isGranted) return;
    setState(() {
      _isRecording = true;
      _transcribedText = '';
      _errorMessage = '';
      _soundLevel = 0.0;
      _isPronunciationWrong = false;
    });
    await _speech.listen(
      onResult: (result) => setState(() => _transcribedText = result.recognizedWords),
      onSoundLevelChange: (level) => setState(() => _soundLevel = level.clamp(0, 100)),
      listenFor: const Duration(seconds: 6),
      localeId: _getLocaleId(widget.selectedLanguage),
    );
    Future.delayed(const Duration(seconds: 6), _stopRecording);
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    await _speech.stop();
    if (mounted) {
      setState(() => _isRecording = false);
      if (_transcribedText.isNotEmpty) {
        _processPronunciation();
      } else {
        setState(() => _errorMessage = 'No speech detected');
      }
    }
  }

  Future<void> _processPronunciation() async {
    setState(() => _isProcessing = true);
    final feedback = await _geminiService.analyzePronunciation(_transcribedText, _currentWord, widget.selectedLanguage);
    if (mounted) {
      setState(() {
        _correctedText = feedback['corrected']!;
        _pronunciationFeedback = feedback['feedback']!;
        _phoneticCorrect = feedback['phonetic']!;
        _attemptCount++;
        _isProcessing = false;
      });

      String normalizedTranscribed = _transcribedText.replaceAll(' ', '').toLowerCase();
      String normalizedCurrent = _currentWord.replaceAll(' ', '').toLowerCase();

      if (normalizedTranscribed == normalizedCurrent) {
        setState(() => _isPronunciationWrong = false);
        _totalWords++;
        _confettiController.play();
        setState(() => _showLoading = true);
        await Future.delayed(const Duration(milliseconds: 500));
        await _checkProgress();
        setState(() => _showLoading = false);
      } else {
        setState(() => _isPronunciationWrong = true);
        await _voiceService.speak(_correctedText, widget.selectedLanguage);
      }
    }
  }

  Future<void> _skipWord() async {
    setState(() => _showLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    await _loadNextWord();
    setState(() => _showLoading = false);
  }

  Future<void> _checkProgress() async {
    if (_totalWords % 5 == 0) {
      int xpEarned = (100 - (_attemptCount.clamp(0, 10) * 10)).clamp(0, 100);
      _xpPoints += xpEarned;
      bool? continueGame = await _showContinueDialog(xpEarned);
      if (continueGame != true && mounted) {
        Navigator.pop(context);
        return;
      }
    }
    await _loadNextWord();
  }

  Future<bool?> _showContinueDialog(int xpEarned) {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Progress Check',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white70 : const Color(0xFF2196F3),
          ),
        ),
        content: Text(
          'Completed $_totalWords words!\nXP Earned: $xpEarned\nTotal XP: $_xpPoints\nContinue?',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No',
              style: GoogleFonts.poppins(color: isDarkMode ? Colors.red[400] : Colors.red[600]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Yes',
              style: GoogleFonts.poppins(color: isDarkMode ? Colors.green[400] : Colors.green[600]),
            ),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient
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
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'Pronounce - ${widget.selectedLanguage}',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFF2196F3),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_xpPoints XP',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: const Color(0xFF2196F3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LinearProgressIndicator(
                    value: (_totalWords % 5) / 5,
                    backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF2196F3)),
                    minHeight: 4,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildWordCard(),
                        const SizedBox(height: 24),
                        _buildControlsSection(),
                        const SizedBox(height: 16),
                        _buildVoiceVisualizer(),
                        const SizedBox(height: 24),
                        if (_errorMessage.isNotEmpty) _buildErrorCard(),
                        if (!_isProcessing && _errorMessage.isEmpty && _transcribedText.isNotEmpty) _buildFeedbackCard(),
                      ],
                    ).animate().fadeIn(
                      duration: 600.ms,
                    ).slideY(
                      begin: 0.2,
                      end: 0,
                      duration: 600.ms,
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
              ],
            ),
            if (_showLoading) _buildShimmerLoader(),
            if (!_isPronunciationWrong && _transcribedText.trim().replaceAll(' ', '').toLowerCase() == _currentWord.trim().replaceAll(' ', '').toLowerCase())
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: -math.pi / 2,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.1,
                colors: const [Colors.blueAccent, Colors.lightBlue, Colors.white],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordCard() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return GestureDetector(
      onTap: () async {
        if (_currentWord.isNotEmpty) {
          print('Tapped word: $_currentWord');
          await _voiceService.speak(_currentWord, widget.selectedLanguage);
        } else {
          print('No word to speak');
        }
      },
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.transparent,
              width: 2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2196F3).withOpacity(0.1),
                const Color(0xFF2196F3).withOpacity(0.3),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.language,
                    color: const Color(0xFF2196F3),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pronunciation Practice',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  _currentWord.isEmpty ? '...' : _currentWord,
                  style: GoogleFonts.poppins(
                    fontSize: _currentWord.length > 12 ? 28 : 36,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  _phoneticCorrect,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  _currentMeaning.isEmpty ? '' : '($_currentMeaning)',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceVisualizer() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) => CustomPaint(
        painter: _WavePainter(
          progress: _soundLevel / 100,
          animationValue: _animationController.value,
          isActive: _isRecording,
          color: isDarkMode ? Colors.white70 : const Color(0xFF2196F3),
        ),
        size: const Size(200, 80),
      ),
    );
  }

  Widget _buildControlsSection() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _isRecording
              ? FloatingActionButton.large(
            key: const ValueKey('stop'),
            backgroundColor: Colors.red[400],
            onPressed: _stopRecording,
            child: const Icon(Icons.stop, size: 32, color: Colors.white),
          )
              : FloatingActionButton.large(
            key: const ValueKey('mic'),
            backgroundColor: const Color(0xFF2196F3),
            onPressed: _startRecording,
            child: const Icon(Icons.mic_none, size: 32, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        if (_attemptCount >= 5)
          AnimatedOpacity(
            opacity: _attemptCount >= 5 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: TextButton.icon(
              onPressed: _skipWord,
              icon: Icon(
                Icons.skip_next,
                color: isDarkMode ? Colors.white70 : const Color(0xFF2196F3),
                size: 20,
              ),
              label: Text(
                'Skip',
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white70 : const Color(0xFF2196F3),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeedbackCard() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
        padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
    color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
    BoxShadow(
    color: Colors.black.withOpacity(0.1),
    blurRadius: 12,
    offset: const Offset(0, 4),
    ),
    ],
    border: Border.all(
    color: Colors.transparent,
    width: 2,
    ),
    gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: _isPronunciationWrong
    ? [
    Colors.red.withOpacity(0.1),
    Colors.red.withOpacity(0.3),
    ]
        : [
    const Color(0xFF2196F3).withOpacity(0.1),
    const Color(0xFF2196F3).withOpacity(0.3),
    ],
    ),
    ),
    child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
    Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
    Icon(
      _isPronunciationWrong ? Icons.close : Icons.check_circle,
      color: Colors.red,
      size: 18,
    ),
      const SizedBox(width: 6),
      Text(
        _isPronunciationWrong ? 'Wrong Pronunciation' : 'Correct Pronunciation',
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white70 : Colors.black87,
        ),
      ),
    ],
    ),
      const SizedBox(height: 12),
      _buildAnalysisRow('You Said:', _transcribedText),
      _buildAnalysisRow('Correct:', _correctedText),
      const SizedBox(height: 12),
      LinearProgressIndicator(
        value: (1 - (_attemptCount / 10)).clamp(0.0, 1.0),
        backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
        valueColor: AlwaysStoppedAnimation<Color>(
          _isPronunciationWrong ? Colors.red : const Color(0xFF2196F3),
        ),
        minHeight: 6,
        borderRadius: BorderRadius.circular(10),
      ),
      const SizedBox(height: 12),
      Text(
        _pronunciationFeedback,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: isDarkMode ? Colors.white54 : Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    ],
    ),
    ).animate().fadeIn(
      duration: 600.ms,
      delay: 200.ms,
    ).slideX(
      begin: 0.2,
      end: 0,
      duration: 600.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildAnalysisRow(String label, String value) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: isDarkMode ? Colors.white54 : Colors.grey[600],
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: _isPronunciationWrong
                    ? (isDarkMode ? Colors.red[400] : Colors.red[600])
                    : (isDarkMode ? Colors.white70 : const Color(0xFF2196F3)),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.right,
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.red[900]!.withOpacity(0.2) : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: isDarkMode ? Colors.red[400] : Colors.red[800],
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage,
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.red[400] : Colors.red[800],
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(
      duration: 600.ms,
      delay: 200.ms,
    ).slideX(
      begin: 0.2,
      end: 0,
      duration: 600.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildShimmerLoader() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return IgnorePointer(
      child: Container(
        color: isDarkMode ? Colors.black54 : Colors.black26,
        child: Center(
          child: ShimmerLoader(
            baseColor: isDarkMode ? Colors.grey[700]! : const Color(0xFF2196F3).withOpacity(0.2),
            highlightColor: isDarkMode ? Colors.grey[500]! : const Color(0xFF2196F3).withOpacity(0.4),
            child: Text(
              'Perfecting Pronunciation...',
              style: GoogleFonts.poppins(
                fontSize: 24,
                color: isDarkMode ? Colors.white70 : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _voiceService.stop();
    _animationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final double animationValue;
  final bool isActive;
  final Color color;

  _WavePainter({
    required this.progress,
    required this.animationValue,
    required this.isActive,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(isActive ? 0.6 : 0.3)
      ..style = PaintingStyle.fill;
    final path = Path();
    final waveHeight = size.height * 0.4;
    final baseHeight = size.height * (1 - progress);
    path.moveTo(0, baseHeight);
    for (double i = 0; i < size.width; i++) {
      final angle = (i / size.width * 4 * math.pi) + (animationValue * 2 * math.pi);
      final y = baseHeight + math.sin(angle) * waveHeight;
      path.lineTo(i, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.progress != progress ||
          oldDelegate.animationValue != animationValue ||
          oldDelegate.isActive != isActive ||
          oldDelegate.color != color;
}

class ShimmerLoader extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerLoader({
    required this.child,
    required this.baseColor,
    required this.highlightColor,
    Key? key,
  }) : super(key: key);

  @override
  _ShimmerLoaderState createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment(-1.0 + (2 * _controller.value), 0),
          end: Alignment(1.0 + (2 * _controller.value), 0),
        ).createShader(bounds),
        child: widget.child,
      ),
    );
  }
}