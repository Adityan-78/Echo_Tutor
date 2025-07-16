import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/gemini_service_quiz.dart';
import '../services/voice_service.dart';
import '../database/db_helper.dart';
import '../providers/theme_provider.dart';

class QuizScreen extends StatefulWidget {
  final String selectedLanguage;
  final String userEmail;

  const QuizScreen({required this.selectedLanguage, required this.userEmail, Key? key})
      : super(key: key);

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final GeminiServiceQuiz _geminiService = GeminiServiceQuiz();
  final VoiceService _voiceService = VoiceService();
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  String? _selectedDifficulty;
  int _score = 0;
  bool _isLoading = false;
  bool _isQuestionPlayed = false;
  Set<String> _usedQuestions = {};
  OverlayEntry? _overlayEntry;
  int _secondsElapsed = 0;
  bool _isTimerRunning = false;
  String? _selectedAnswer;
  bool _isAnswerChecked = false;

  @override
  void initState() {
    super.initState();
    _voiceService.initializeTts();
  }

  Future<void> _loadQuestions(String difficulty) async {
    setState(() {
      _isLoading = true;
      _isTimerRunning = true;
    });

    _usedQuestions.clear();
    final questions = await _geminiService.generateQuizQuestions(widget.selectedLanguage, difficulty);

    List<Map<String, dynamic>> uniqueQuestions = [];
    for (var q in questions) {
      String questionKey = '${q['question']}-${q['type']}-${q['direction']}';
      if (!_usedQuestions.contains(questionKey) && uniqueQuestions.length < 10) {
        uniqueQuestions.add(q);
        _usedQuestions.add(questionKey);
      }
    }

    while (uniqueQuestions.length < 10) {
      final extraQuestions = await _geminiService.generateQuizQuestions(widget.selectedLanguage, difficulty);
      for (var q in extraQuestions) {
        String questionKey = '${q['question']}-${q['type']}-${q['direction']}';
        if (!_usedQuestions.contains(questionKey) && uniqueQuestions.length < 10) {
          uniqueQuestions.add(q);
          _usedQuestions.add(questionKey);
        }
      }
    }

    setState(() {
      _questions = uniqueQuestions;
      _currentQuestionIndex = 0;
      _score = 0;
      _isQuestionPlayed = false;
      _isLoading = false;
      _secondsElapsed = 0;
      _selectedAnswer = null;
      _isAnswerChecked = false;
    });

    if (_questions.isNotEmpty && _questions[0]['type'] == 'voice') {
      _playCurrentQuestion();
    }

    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_isTimerRunning) return false;
      setState(() {
        _secondsElapsed++;
      });
      return true;
    });
  }

  String _formatTimer(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _playCurrentQuestion() async {
    final currentQuestion = _questions[_currentQuestionIndex];
    await _voiceService.speak(currentQuestion['question'], currentQuestion['questionLanguage']);
    setState(() => _isQuestionPlayed = true);
  }

  Future<void> _speakText(String text, String language) async {
    await _voiceService.speak(text, language);
  }

  void _checkAnswer(String selectedAnswer) async {
    final currentQuestion = _questions[_currentQuestionIndex];
    bool isCorrect = selectedAnswer == currentQuestion['correctAnswer'];

    setState(() {
      _selectedAnswer = selectedAnswer;
      _isAnswerChecked = true;
    });

    if (isCorrect) {
      _score++;
      _showFeedback(true);
    } else {
      _showFeedback(false, currentQuestion['correctAnswer']);
    }

    // Wait longer to show feedback and highlight correct answer
    await Future.delayed(const Duration(seconds: 2));
    if (!isCorrect) {
      // Highlight correct answer
      setState(() {
        _selectedAnswer = currentQuestion['correctAnswer'];
      });
      await Future.delayed(const Duration(seconds: 2));
    }
    _nextQuestion();
  }

  void _showFeedback(bool isCorrect, [String? correctAnswer]) {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.4,
        left: MediaQuery.of(context).size.width * 0.5 - 30,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCorrect ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
            child: isCorrect
                ? const Icon(Icons.check, color: Colors.white, size: 40)
                : const Icon(Icons.close, color: Colors.white, size: 40),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);

    Future.delayed(const Duration(seconds: 2), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _isQuestionPlayed = false;
        _selectedAnswer = null;
        _isAnswerChecked = false;
      });
      if (_questions[_currentQuestionIndex]['type'] == 'voice') {
        _playCurrentQuestion();
      }
    } else {
      _endQuiz();
    }
  }

  void _endQuiz() async {
    setState(() {
      _isTimerRunning = false;
    });

    final xpEarned = _calculateXp();
    await DatabaseHelper.instance.updateUserXp(widget.userEmail, xpEarned);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Quiz Completed!", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          "Score: $_score/10\nXP Earned: $xpEarned\nTime: ${_formatTimer(_secondsElapsed)}",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, xpEarned);
            },
            child: Text("OK", style: GoogleFonts.poppins(color: const Color(0xFF2196F3))),
          ),
        ],
      ),
    );
  }

  int _calculateXp() {
    switch (_selectedDifficulty) {
      case 'Basic':
        return _score * 5;
      case 'Intermediate':
        return _score * 10;
      case 'Advanced':
        return _score * 20;
      default:
        return 0;
    }
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
            _selectedDifficulty == null
                ? _buildDifficultySelection(size)
                : _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildQuestion(size),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultySelection(Size size) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Select Difficulty",
            style: GoogleFonts.poppins(
              fontSize: size.width * 0.06,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          SizedBox(height: size.height * 0.04),
          _buildDifficultyButton("Basic", Colors.green, size),
          SizedBox(height: size.height * 0.02),
          _buildDifficultyButton("Intermediate", Colors.orange, size),
          SizedBox(height: size.height * 0.02),
          _buildDifficultyButton("Advanced", Colors.red, size),
        ],
      ),
    );
  }

  Widget _buildDifficultyButton(String difficulty, Color color, Size size) {
    return SizedBox(
      width: size.width * 0.5,
      height: size.height * 0.07,
      child: ElevatedButton(
        onPressed: () {
          setState(() => _selectedDifficulty = difficulty);
          _loadQuestions(difficulty);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.08, vertical: size.height * 0.02),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.width * 0.03)),
        ),
        child: Text(
          difficulty,
          style: GoogleFonts.poppins(
            fontSize: size.width * 0.045,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion(Size size) {
    final question = _questions[_currentQuestionIndex];
    final questionLanguage = question['questionLanguage'];
    final answerLanguage = question['direction'] == 'toEnglish' ? 'English' : widget.selectedLanguage;
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Column(
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
                "${(_currentQuestionIndex + 1).toString().padLeft(2, '0')} of ${_questions.length.toString().padLeft(2, '0')}",
                style: GoogleFonts.poppins(
                  fontSize: size.width * 0.04,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: size.width * 0.03, vertical: size.height * 0.008),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(size.width * 0.05),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: const Color(0xFF2196F3),
                      size: size.width * 0.04,
                    ),
                    SizedBox(width: size.width * 0.01),
                    Text(
                      _formatTimer(_secondsElapsed),
                      style: GoogleFonts.poppins(
                        fontSize: size.width * 0.035,
                        color: const Color(0xFF2196F3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
          child: LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _questions.length,
            backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF2196F3)),
            minHeight: size.height * 0.005,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(size.width * 0.06),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(size.width * 0.04),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(size.width * 0.04),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: size.width * 0.03,
                        offset: Offset(0, size.height * 0.005),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.transparent,
                      width: size.width * 0.005,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.language,
                            color: const Color(0xFF2196F3),
                            size: size.width * 0.05,
                          ),
                          SizedBox(width: size.width * 0.02),
                          Text(
                            "Language Quiz",
                            style: GoogleFonts.poppins(
                              fontSize: size.width * 0.035,
                              color: isDarkMode ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: size.height * 0.015),
                      if (question['type'] == 'text')
                        Text(
                          question['question'],
                          style: GoogleFonts.poppins(
                            fontSize: size.width * 0.05,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white70 : Colors.black87,
                          ),
                        )
                      else
                        Text(
                          question['direction'] == 'toEnglish' ? "What does it mean?" : "What was spoken?",
                          style: GoogleFonts.poppins(
                            fontSize: size.width * 0.05,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      SizedBox(height: size.height * 0.02),
                      if (question['type'] == 'voice')
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.volume_up,
                                color: const Color(0xFF2196F3),
                                size: size.width * 0.075,
                              ),
                              onPressed: _isQuestionPlayed ? _playCurrentQuestion : null,
                              tooltip: 'Play question again',
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                SizedBox(height: size.height * 0.03),
                ...question['options'].map((option) {
                  bool isSelected = _selectedAnswer == option;
                  bool isCorrect = option == question['correctAnswer'];
                  bool showFeedback = _isAnswerChecked && isSelected;
                  bool highlightCorrect = _isAnswerChecked && isCorrect;

                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: size.height * 0.01),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isAnswerChecked ? null : () => _checkAnswer(option),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: highlightCorrect
                              ? Colors.green.withOpacity(0.3)
                              : showFeedback
                              ? (isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1))
                              : (isDarkMode ? const Color(0xFF2A2A2A) : Colors.white),
                          foregroundColor: isDarkMode ? Colors.white70 : Colors.black87,
                          padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.02),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.width * 0.03)),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                option,
                                style: GoogleFonts.poppins(
                                  fontSize: size.width * 0.04,
                                  color: isDarkMode ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                            if (showFeedback || highlightCorrect)
                              Icon(
                                isCorrect ? Icons.check : Icons.close,
                                color: isCorrect ? Colors.green : Colors.red,
                                size: size.width * 0.05,
                              )
                            else
                              IconButton(
                                icon: Icon(
                                  Icons.volume_up,
                                  color: const Color(0xFF2196F3),
                                  size: size.width * 0.05,
                                ),
                                onPressed: () => _speakText(option, answerLanguage),
                                tooltip: 'Read option aloud',
                              ),
                          ],
                        ),
                      ),
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
                }).toList(),
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
    );
  }

  @override
  void dispose() {
    _voiceService.stop();
    _overlayEntry?.remove();
    _isTimerRunning = false;
    super.dispose();
  }
}