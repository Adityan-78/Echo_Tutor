import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'package:flip_card/flip_card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/conversation_handler.dart';
import '../services/gemini_service1.dart';
import '../services/voice_service.dart';
import '../providers/theme_provider.dart';

class LessonScreen extends StatefulWidget {
  final String selectedLanguage;

  const LessonScreen({required this.selectedLanguage, Key? key}) : super(key: key);

  @override
  _LessonScreenState createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> with SingleTickerProviderStateMixin {
  late final VoiceService _voiceService;
  late ConversationHandler _conversationHandler;
  late final AnimationController _progressController;
  late final ConfettiController _confettiController;

  String? _userLevel;
  String _currentStage = 'vocabulary';
  List<Map<String, dynamic>> _lessonContent = [];
  List<Map<String, dynamic>> _assessment = [];
  bool _isLoading = false;
  bool _showLevelSelection = true;
  bool _showAssessment = false;
  final TextEditingController _inputController = TextEditingController();
  int _currentCardIndex = 0;
  final List<String> _learnedWords = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
  }

  Future<void> _initializeServices() async {
    _voiceService = VoiceService();
    _conversationHandler = ConversationHandler(
      geminiService: GeminiService1(),
      voiceService: _voiceService,
      language: widget.selectedLanguage,
      level: _userLevel ?? 'beginner',
    );
  }

  void _nextCard() {
    if (_currentCardIndex < _lessonContent.length - 1) {
      setState(() => _currentCardIndex++);
    } else if (_assessment.isNotEmpty) {
      setState(() => _showAssessment = true);
      _confettiController.play();
    }
  }

  void _changeStage(String newStage) {
    setState(() {
      _currentStage = newStage;
      _lessonContent.clear();
      _assessment.clear();
      _currentCardIndex = 0;
      _showAssessment = false;
      _inputController.clear();
    });
  }

  Future<void> _startLesson(String userInput) async {
    if (userInput.isEmpty) return;
    setState(() => _isLoading = true);
    final response = await _conversationHandler.geminiService.getLessonContent(
      widget.selectedLanguage,
      _userLevel!,
      _currentStage,
      userInput,
      _learnedWords,
    );
    setState(() {
      _lessonContent = [
        _currentStage == 'vocabulary'
            ? response['vocabulary'] ?? {}
            : _currentStage == 'sentences'
            ? response['sentences'] ?? {}
            : response['grammar'] ?? {}
      ];
      _assessment = List<Map<String, dynamic>>.from(response['assessment'] ?? []).map((q) {
        final correctAnswer = q['answer'] as String;
        final options = _generateQuizOptions(correctAnswer, widget.selectedLanguage, q['question'] as String);
        return {
          ...q,
          'options': options,
          'selected': null,
          'attempts': 0,
          'clues': _generateClues(q),
          'checkedAnswer': false,
          'isCorrect': false,
        };
      }).toList();
      _currentCardIndex = 0;
      if (_currentStage == 'vocabulary' && _lessonContent.isNotEmpty) {
        _learnedWords.add(_lessonContent[0]['word'] as String);
      }
      _isLoading = false;
      _inputController.clear();
    });
  }

  List<String> _generateClues(Map<String, dynamic> question) {
    String answer;
    if (question['answer'] is String) {
      answer = question['answer'] as String;
    } else if (question['answer'] is Map) {
      final answerMap = question['answer'] as Map;
      answer = answerMap['word'] as String? ?? answerMap['example'] as String? ?? 'unknown';
    } else {
      answer = 'unknown';
    }
    final relatedContent = _lessonContent.isNotEmpty
        ? (_lessonContent[0]['translation'] as String? ?? _lessonContent[0]['example'] as String? ?? 'this lesson')
        : 'this lesson';
    return [
      "Hint: The answer starts with '${answer.isNotEmpty ? answer[0] : '?'}'.",
      "Hint: It’s related to '$relatedContent'.",
      "Hint: Think about the ${_currentStage} we just covered!",
    ];
  }

  List<String> _generateQuizOptions(String correctAnswer, String language, String question) {
    final optionsMap = {
      'Spanish': {
        'house': ['casa', 'hogar', 'vivienda', 'apartamento'],
        'dog': ['perro', 'can', 'lobo', 'cachorro'],
        'hello': ['hola', 'saludos', 'buenos días', 'hey'],
        'friend': ['amigo', 'compañero', 'colega', 'socio'],
      },
      'Hindi': {
        'house': ['घर', 'मकान', 'आवास', 'निवास'],
        'dog': ['कुत्ता', 'श्वान', 'पिल्ला', 'भेड़िया'],
        'hello': ['हाय', 'हेलो', 'नमस्ते', 'हाय'],
        'friend': ['दोस्त', 'मित्र', 'सहेली', 'यार'],
      },
      'Arabic': {
        'house': ['بيت', 'منزل', 'دار', 'شقة'],
        'dog': ['كلب', 'جرو', 'ذئب', 'حيوان'],
        'hello': ['مرحبا', 'أهلا', 'سلام', 'هلا'],
        'friend': ['صديق', 'رفيق', 'صاحب', 'زميل'],
      },
      'French': {
        'house': ['maison', 'foyer', 'logement', 'demeure'],
        'dog': ['chien', 'caniche', 'loup', 'chiot'],
        'hello': ['bonjour', 'salut', 'coucou', 'hé'],
        'friend': ['ami', 'copain', 'collègue', 'pote'],
      },
      'English': {
        'house': ['home', 'residence', 'dwelling', 'apartment'],
        'dog': ['dog', 'puppy', 'hound', 'canine'],
        'hello': ['hello', 'hi', 'hey', 'greetings'],
        'friend': ['friend', 'buddy', 'pal', 'mate'],
      },
    };

    final languageOptions = optionsMap[language] ?? {};
    final wordKey = correctAnswer.toLowerCase();
    final options = languageOptions[wordKey] ?? ['Option 1', 'Option 2', 'Option 3', 'Option 4'];

    final filteredOptions = options.where((opt) => opt != correctAnswer).toList();
    filteredOptions.shuffle();
    final result = [correctAnswer, ...filteredOptions.take(3)];
    result.shuffle();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                        "Lessons in ${widget.selectedLanguage}",
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
                if (!_showLevelSelection) _buildStageSelector(size),
                Expanded(
                  child: _showLevelSelection
                      ? _buildLevelSelection(size)
                      : _isLoading
                      ? Center(
                    child: CircularProgressIndicator(
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF2196F3)),
                    ).animate().scale(),
                  )
                      : _lessonContent.isEmpty
                      ? _buildInputPrompt(size)
                      : _showAssessment
                      ? _buildAssessment(size)
                      : _buildFlashCard(size),
                ),
                if (!_showLevelSelection) _buildChatInput(size),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageSelector(Size size) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final stages = _userLevel == 'intermediate' ? ['vocabulary', 'sentences', 'grammar'] : ['vocabulary', 'sentences'];

    return Container(
      height: size.height * 0.07,
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.02),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: stages.map((stage) => _buildStageButton(stage, size)).toList(),
        ),
      ),
    );
  }

  Widget _buildStageButton(String stage, Size size) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.symmetric(horizontal: size.width * 0.01),
      decoration: BoxDecoration(
        color: _currentStage == stage ? const Color(0xFF2196F3) : Colors.transparent,
        borderRadius: BorderRadius.circular(size.width * 0.05),
        border: Border.all(
          color: _currentStage == stage
              ? const Color(0xFF2196F3)
              : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
          width: size.width * 0.002,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(size.width * 0.05),
          onTap: () => _changeStage(stage),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.03, vertical: size.height * 0.01),
            child: Text(
              stage.toUpperCase(),
              style: GoogleFonts.poppins(
                color: _currentStage == stage
                    ? Colors.white
                    : (isDarkMode ? Colors.white54 : Colors.grey[600]),
                fontWeight: FontWeight.w600,
                fontSize: size.width * 0.035,
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildLevelSelection(Size size) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Choose Your Level",
            style: GoogleFonts.poppins(
              fontSize: size.width * 0.06,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.black87,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),
          SizedBox(height: size.height * 0.05),
          ...['Beginner', 'Intermediate'].map((level) => Padding(
            padding: EdgeInsets.symmetric(vertical: size.height * 0.015),
            child: ElevatedButton(
              onPressed: () => setState(() {
                _userLevel = level.toLowerCase();
                _showLevelSelection = false;
                _conversationHandler.updateLevel(level.toLowerCase());
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: size.width * 0.08, vertical: size.height * 0.02),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.width * 0.03)),
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.1),
              ),
              child: Text(
                level,
                style: GoogleFonts.poppins(fontSize: size.width * 0.04, fontWeight: FontWeight.w600),
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOut),
          )),
        ],
      ),
    );
  }

  Widget _buildInputPrompt(Size size) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "What do you want to learn?",
            style: GoogleFonts.poppins(
              fontSize: size.width * 0.055,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ).animate().fadeIn(),
          SizedBox(height: size.height * 0.02),
          Text(
            "Type below and hit send!",
            style: GoogleFonts.poppins(
              fontSize: size.width * 0.04,
              color: isDarkMode ? Colors.white54 : Colors.grey[600],
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }

  Widget _buildChatInput(Size size) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: isDarkMode ? Colors.grey[800]! : Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white70 : Colors.black87,
                fontSize: size.width * 0.035,
              ),
              decoration: InputDecoration(
                hintText: "e.g., greetings, food items...",
                hintStyle: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white54 : Colors.grey[400],
                  fontSize: size.width * 0.035,
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(size.width * 0.03),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: size.width * 0.05, vertical: size.height * 0.02),
                suffixIcon: IconButton(
                  icon: Icon(Icons.mic_none_rounded, color: const Color(0xFF2196F3), size: size.width * 0.05),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Voice input not implemented yet!",
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.width * 0.03)),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SizedBox(width: size.width * 0.03),
          FloatingActionButton(
            backgroundColor: const Color(0xFF2196F3),
            elevation: 0,
            mini: true,
            child: Icon(Icons.send_rounded, color: Colors.white, size: size.width * 0.05),
            onPressed: () => _startLesson(_inputController.text),
          ).animate().scale(duration: 300.ms),
        ],
      ),
    );
  }

  Widget _buildFlashCard(Size size) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    if (_lessonContent.isEmpty) return const SizedBox.shrink();
    final card = _lessonContent[_currentCardIndex];
    final textToSpeak = _currentStage == 'vocabulary' ? card['word'] : card['example'];

    return Center(
      child: FlipCard(
        flipOnTouch: true,
        direction: FlipDirection.HORIZONTAL,
        speed: 400,
        front: Container(
          width: size.width * 0.8,
          height: size.height * 0.5,
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3),
            borderRadius: BorderRadius.circular(size.width * 0.06),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: size.width * 0.03, offset: Offset(0, size.height * 0.005)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: size.width * 0.12,
                color: Colors.white.withOpacity(0.8),
              ),
              SizedBox(height: size.height * 0.02),
              Text(
                "Tap to Learn",
                style: GoogleFonts.poppins(
                  fontSize: size.width * 0.07,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ).animate().scale(duration: 300.ms, curve: Curves.easeOut),
        back: Container(
          width: size.width * 0.8,
          height: size.height * 0.5,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(size.width * 0.06),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: size.width * 0.03, offset: Offset(0, size.height * 0.005)),
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
          padding: EdgeInsets.all(size.width * 0.06),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _currentStage == 'vocabulary'
                              ? card['word'] ?? 'N/A'
                              : _currentStage == 'sentences'
                              ? card['structure'] ?? 'N/A'
                              : card['rule'] ?? 'N/A',
                          style: GoogleFonts.poppins(
                            fontSize: size.width * 0.07,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white70 : const Color(0xFF2196F3),
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.volume_up_rounded, color: const Color(0xFF2196F3), size: size.width * 0.05),
                        onPressed: () => _voiceService.speak(textToSpeak, widget.selectedLanguage),
                        tooltip: 'Listen',
                      ),
                    ],
                  ),
                  SizedBox(height: size.height * 0.025),
                  Divider(
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                    height: size.height * 0.001,
                  ),
                  SizedBox(height: size.height * 0.025),
                  Text(
                    _currentStage == 'vocabulary'
                        ? card['translation'] ?? 'N/A'
                        : _currentStage == 'sentences'
                        ? card['example'] ?? 'N/A'
                        : card['explanation'] ?? 'N/A',
                    style: GoogleFonts.poppins(
                      fontSize: size.width * 0.045,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
                  if (_currentStage == 'vocabulary') ...[
                    SizedBox(height: size.height * 0.015),
                    Text(
                      card['english_pronunciation'] ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: size.width * 0.04,
                        color: isDarkMode ? Colors.white54 : const Color(0xFF2196F3).withOpacity(0.9),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: size.height * 0.01),
                    Text(
                      card['pronunciation'] ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: size.width * 0.035,
                        color: isDarkMode ? Colors.white54 : Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_currentStage == 'sentences') ...[
                    SizedBox(height: size.height * 0.015),
                    Text(
                      card['translation'] ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: size.width * 0.04,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ],
              ),
              ElevatedButton(
                onPressed: _nextCard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.08, vertical: size.height * 0.0175),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.width * 0.03)),
                  elevation: 0,
                ),
                child: Text(
                  "Next",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: size.width * 0.035),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),
      ),
    );
  }

  Widget _buildAssessment(Size size) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    bool allCorrect = _assessment.every((q) => q['isCorrect'] == true || q['checkedAnswer'] == true);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(size.width * 0.04),
            itemCount: _assessment.length + 1,
            itemBuilder: (context, index) {
              if (index == _assessment.length) {
                return Padding(
                  padding: EdgeInsets.only(top: size.height * 0.02),
                  child: ElevatedButton(
                    onPressed: allCorrect
                        ? () => setState(() {
                      _showAssessment = false;
                      if (_currentStage == 'vocabulary') {
                        _changeStage('sentences');
                      } else if (_currentStage == 'sentences' && _userLevel == 'intermediate') {
                        _changeStage('grammar');
                      } else {
                        _lessonContent.clear();
                        _assessment.clear();
                      }
                    })
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: size.width * 0.08, vertical: size.height * 0.0175),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.width * 0.03)),
                      elevation: 4,
                      disabledBackgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    ),
                    child: Text(
                      _currentStage != 'grammar' ? "Next Stage" : "Restart",
                      style: GoogleFonts.poppins(fontSize: size.width * 0.04, fontWeight: FontWeight.w600),
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                );
              }
              final q = _assessment[index];
              final isCorrect = q['isCorrect'] == true;
              final showClue = q['attempts'] > 0 && !isCorrect && !(q['checkedAnswer'] == true);
              return Container(
                margin: EdgeInsets.only(bottom: size.height * 0.015),
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
                child: Padding(
                  padding: EdgeInsets.all(size.width * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q['question'] ?? 'N/A',
                        style: GoogleFonts.poppins(
                          fontSize: size.width * 0.045,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      SizedBox(height: size.height * 0.015),
                      if (q['type'] == 'match' || q['type'] == 'pick')
                        Column(
                          children: (q['options'] as List<dynamic>).map<Widget>((opt) {
                            return RadioListTile<String>(
                              value: opt,
                              groupValue: q['selected'],
                              onChanged: q['checkedAnswer'] == true
                                  ? null
                                  : (value) => setState(() {
                                q['selected'] = value;
                                q['isCorrect'] = value == q['answer'];
                                if (!q['isCorrect']) q['attempts']++;
                              }),
                              title: Text(
                                opt,
                                style: GoogleFonts.poppins(
                                  fontSize: size.width * 0.04,
                                  color: isDarkMode ? Colors.white54 : Colors.grey[700],
                                ),
                              ),
                              activeColor: const Color(0xFF2196F3),
                              contentPadding: EdgeInsets.zero,
                            );
                          }).toList(),
                        )
                      else
                        Column(
                          children: [
                            TextField(
                              enabled: q['checkedAnswer'] != true,
                              style: GoogleFonts.poppins(
                                color: isDarkMode ? Colors.white70 : Colors.black87,
                                fontSize: size.width * 0.035,
                              ),
                              decoration: InputDecoration(
                                hintText: "Type your answer",
                                hintStyle: GoogleFonts.poppins(
                                  color: isDarkMode ? Colors.white54 : Colors.grey[400],
                                  fontSize: size.width * 0.035,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(size.width * 0.03),
                                ),
                                filled: true,
                                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(size.width * 0.03),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(size.width * 0.03),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2196F3),
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (value) => setState(() {
                                q['selected'] = value;
                                q['isCorrect'] = value.trim().toLowerCase() == q['answer'].trim().toLowerCase();
                                if (!q['isCorrect'] && value.isNotEmpty) q['attempts']++;
                              }),
                            ),
                            if (q['selected'] != null && q['selected'].isNotEmpty && !q['isCorrect'] && !(q['checkedAnswer'] == true))
                              Padding(
                                padding: EdgeInsets.only(top: size.height * 0.015),
                                child: Text(
                                  "Incorrect, try again!",
                                  style: GoogleFonts.poppins(
                                    fontSize: size.width * 0.035,
                                    color: isDarkMode ? Colors.red[400] : Colors.redAccent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      if (showClue) ...[
                        SizedBox(height: size.height * 0.015),
                        Text(
                          q['clues'][q['attempts'] - 1 < q['clues'].length
                              ? q['attempts'] - 1
                              : q['clues'].length - 1],
                          style: GoogleFonts.poppins(
                            fontSize: size.width * 0.035,
                            color: Colors.amber[800],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if (q['attempts'] > 0 && !isCorrect && !(q['checkedAnswer'] == true)) ...[
                        SizedBox(height: size.height * 0.015),
                        TextButton(
                          onPressed: () => setState(() {
                            q['checkedAnswer'] = true;
                            q['selected'] = q['answer'];
                            q['isCorrect'] = true;
                          }),
                          child: Text(
                            "Check Answer",
                            style: GoogleFonts.poppins(
                              color: isDarkMode ? Colors.red[400] : Colors.redAccent,
                              fontSize: size.width * 0.035,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (isCorrect || q['checkedAnswer'] == true) ...[
                        SizedBox(height: size.height * 0.015),
                        Text(
                          isCorrect ? "Correct!" : "Answer: ${q['answer']}",
                          style: GoogleFonts.poppins(
                            fontSize: size.width * 0.04,
                            color: isCorrect
                                ? (isDarkMode ? Colors.green[400] : Colors.green[700])
                                : (isDarkMode ? Colors.red[400] : Colors.redAccent),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ).animate().slideX(
                begin: 0.3,
                delay: Duration(milliseconds: 100 * index),
                duration: 600.ms,
                curve: Curves.easeOut,
              );
            },
          ),
        ),
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirection: -math.pi / 2,
          emissionFrequency: 0.05,
          numberOfParticles: 20,
          gravity: 0.1,
          colors: const [Color(0xFF2196F3), Colors.green, Colors.orange],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    _confettiController.dispose();
    _inputController.dispose();
    super.dispose();
  }
}