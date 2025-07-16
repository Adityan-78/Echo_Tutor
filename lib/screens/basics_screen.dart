import 'dart:async';
import 'package:flutter/cupertino.dart' as IconData;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/gemini_service_basics.dart';
import '../services/voice_service.dart';
import '../providers/theme_provider.dart';

class BasicsScreen extends StatefulWidget {
  final String selectedLanguage;
  final String userEmail;

  const BasicsScreen({required this.selectedLanguage, required this.userEmail, Key? key})
      : super(key: key);

  @override
  _BasicsScreenState createState() => _BasicsScreenState();
}

class _BasicsScreenState extends State<BasicsScreen> with SingleTickerProviderStateMixin {
  late GeminiServiceBasics _geminiService;
  late VoiceService _voiceService;
  final PageController _pageController = PageController(viewportFraction: 0.85);
  String _selectedOption = '';
  List<Map<String, String>> _content = [];
  int _currentIndex = 0;
  bool _isAssessmentMode = false;
  List<Map<String, String>> _assessmentQuestions = [];
  int _assessmentIndex = 0;
  int _correctAnswers = 0;
  int _batchIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiServiceBasics();
    _voiceService = VoiceService();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_animationController);
  }

  Future<void> _loadContent(String option, {bool isContinuation = false}) async {
    if (!isContinuation) {
      setState(() {
        _selectedOption = option;
        _content.clear();
        _batchIndex = 0;
      });
    }

    List<Map<String, String>> newContent;
    if (option == "alphabets") {
      newContent = await _geminiService.getAlphabets(widget.selectedLanguage);
    } else if (option == "numbers") {
      newContent = await _geminiService.getNumbers(widget.selectedLanguage, _batchIndex);
    } else {
      newContent = await _geminiService.getBasicWords(widget.selectedLanguage, _batchIndex);
    }

    if (newContent.isEmpty) {
      print("❌ No content loaded for $option (batch $_batchIndex) in ${widget.selectedLanguage}");
    }

    if (mounted) {
      setState(() {
        _content.addAll(newContent);
        _currentIndex = isContinuation ? _content.length - newContent.length : 0;
        _isAssessmentMode = false;
      });
      _animationController.forward(from: 0);
      if (_content.isNotEmpty) {
        _voiceService.speak(_content[_currentIndex]['text']!, widget.selectedLanguage);
      }
    }
  }

  void _startAssessment() {
    final shuffledContent = List<Map<String, String>>.from(_content)..shuffle();
    if (mounted) {
      setState(() {
        _assessmentQuestions = shuffledContent;
        _assessmentIndex = 0;
        _correctAnswers = 0;
        _isAssessmentMode = true;
      });
      _animationController.forward(from: 0);
    }
  }

  void _checkAnswer(String selectedAnswer) {
    final correctAnswer = _assessmentQuestions[_assessmentIndex]['text']!;
    if (selectedAnswer == correctAnswer) {
      _correctAnswers++;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Correct! 🎉",
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Oops, wrong!",
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 1),
        ),
      );
    }
    if (_assessmentIndex < _assessmentQuestions.length - 1) {
      if (mounted) {
        setState(() => _assessmentIndex++);
        _animationController.forward(from: 0);
      }
    } else {
      _endAssessment();
    }
  }

  void _endAssessment() {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Assessment Done!",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white70 : const Color(0xFF2196F3),
          ),
        ),
        content: Text(
          "You scored $_correctAnswers out of ${_assessmentQuestions.length}!",
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) setState(() => _isAssessmentMode = false);
            },
            child: Text(
              "OK",
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white70 : const Color(0xFF2196F3),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptToContinue() async {
    if (_selectedOption == "alphabets") {
      _startAssessment();
      return;
    }

    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Continue Learning?",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white70 : const Color(0xFF2196F3),
          ),
        ),
        content: Text(
          "Would you like to learn the next set?",
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "No",
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.red[400] : Colors.red[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Yes",
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.green[400] : Colors.green[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldContinue == true && mounted) {
      setState(() => _batchIndex++);
      await _loadContent(_selectedOption, isContinuation: true);
    } else {
      _startAssessment();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    _voiceService.stop();
    super.dispose();
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
                        "Learn ${widget.selectedLanguage} Basics",
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
                if (_isAssessmentMode)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
                    child: LinearProgressIndicator(
                      value: (_assessmentIndex + 1) / _assessmentQuestions.length,
                      backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF2196F3)),
                      minHeight: size.height * 0.005,
                    ),
                  ),
                Expanded(
                  child: _selectedOption.isEmpty
                      ? _buildCarousel(size)
                      : _isAssessmentMode
                      ? _buildAssessment(size)
                      : _buildFlashcard(size),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel(Size size) {
    final options = [
      {"title": "Alphabets", "color": const Color(0xFF4CAF50), "icon": Icons.auto_stories_rounded},
      {"title": "Numbers", "color": const Color(0xFF2196F3), "icon": Icons.numbers},
      {"title": "Basic Words", "color": const Color(0xFF9C27B0), "icon": Icons.translate_rounded},
    ];
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Padding(
      padding: EdgeInsets.all(size.width * 0.06),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Choose a Category',
            style: GoogleFonts.poppins(
              fontSize: size.width * 0.06,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          SizedBox(height: size.height * 0.04),
          Expanded(
            child: ListView.separated(
              itemCount: options.length,
              separatorBuilder: (_, __) => SizedBox(height: size.height * 0.025),
              itemBuilder: (context, index) {
                final option = options[index];
                return Container(
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
                        (option["color"] as Color).withOpacity(0.1),
                        (option["color"] as Color).withOpacity(0.3),
                      ],
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(size.width * 0.04),
                      onTap: () => _loadContent((option["title"] as String).toLowerCase()),
                      child: Padding(
                        padding: EdgeInsets.all(size.width * 0.06),
                        child: Row(
                          children: [
                            Icon(
                              option["icon"] as IconData.IconData,
                              size: size.width * 0.09,
                              color: option["color"] as Color,
                            ),
                            SizedBox(width: size.width * 0.05),
                            Text(
                              option["title"] as String,
                              style: GoogleFonts.poppins(
                                fontSize: size.width * 0.05,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: isDarkMode ? Colors.white54 : Colors.grey[400],
                              size: size.width * 0.06,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(
                  duration: 600.ms,
                  delay: (index * 100).ms,
                ).slideY(
                  begin: 0.2,
                  end: 0,
                  duration: 600.ms,
                  curve: Curves.easeOut,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashcard(Size size) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    if (_content.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
            ),
            SizedBox(height: size.height * 0.03),
            Text(
              "Loading Content...",
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white54 : Colors.black54,
                fontSize: size.width * 0.04,
              ),
            ),
          ],
        ),
      );
    }

    final item = _content[_currentIndex];
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: EdgeInsets.all(size.width * 0.06),
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.all(size.width * 0.08),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item['text']!,
                      style: GoogleFonts.poppins(
                        fontSize: size.width * 0.16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white70 : const Color(0xFF2196F3),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Divider(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                      thickness: size.width * 0.005,
                      height: size.height * 0.05,
                      indent: size.width * 0.05,
                      endIndent: size.width * 0.05,
                    ),
                    Text(
                      item['translation'] ?? 'Translation not available',
                      style: GoogleFonts.poppins(
                        fontSize: size.width * 0.06,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: size.height * 0.02),
                    Text(
                      "Pronunciation: ${item['pronunciation']}",
                      style: GoogleFonts.poppins(
                        fontSize: size.width * 0.045,
                        color: isDarkMode ? Colors.white54 : Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: size.height * 0.04),
                    FloatingActionButton(
                      backgroundColor: const Color(0xFF2196F3),
                      onPressed: () => _voiceService.speak(item['text']!, widget.selectedLanguage),
                      child: Icon(Icons.volume_up_rounded, color: Colors.white, size: size.width * 0.06),
                    ),
                  ],
                ),
              ).animate().fadeIn(
                duration: 600.ms,
              ).slideY(
                begin: 0.2,
                end: 0,
                duration: 600.ms,
                curve: Curves.easeOut,
              ),
            ),
            SizedBox(height: size.height * 0.03),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildControlButton(
                  icon: Icons.chevron_left_rounded,
                  onPressed: _currentIndex > 0 ? () => _navigateCard(-1) : null,
                  size: size,
                ),
                SizedBox(width: size.width * 0.05),
                Text(
                  '${_currentIndex + 1}/${_content.length}',
                  style: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    fontSize: size.width * 0.04,
                  ),
                ),
                SizedBox(width: size.width * 0.05),
                _buildControlButton(
                  icon: Icons.chevron_right_rounded,
                  onPressed: () => _currentIndex < _content.length - 1
                      ? _navigateCard(1)
                      : _promptToContinue(),
                  size: size,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateCard(int direction) {
    setState(() {
      _currentIndex += direction;
      _animationController.forward(from: 0);
    });
    _voiceService.speak(_content[_currentIndex]['text']!, widget.selectedLanguage);
  }

  Widget _buildControlButton({required IconData.IconData icon, VoidCallback? onPressed, required Size size}) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return IconButton(
      iconSize: size.width * 0.09,
      icon: Icon(icon),
      color: const Color(0xFF2196F3),
      disabledColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(size.width * 0.03),
          side: BorderSide(
            color: onPressed != null
                ? const Color(0xFF2196F3)
                : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
            width: size.width * 0.005,
          ),
        ),
        padding: EdgeInsets.all(size.width * 0.03),
      ),
    );
  }

  Widget _buildAssessment(Size size) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final question = _assessmentQuestions[_assessmentIndex];
    final options = _generateOptions(_selectedOption == "alphabets" ? question['pronunciation']! : question['text']!);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: EdgeInsets.all(size.width * 0.06),
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.all(size.width * 0.08),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _selectedOption == "alphabets"
                          ? "Match the pronunciation for:"
                          : "Select the correct translation for:",
                      style: GoogleFonts.poppins(
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        fontSize: size.width * 0.04,
                      ),
                    ),
                    SizedBox(height: size.height * 0.02),
                    Text(
                      _selectedOption == "alphabets" ? question['text']! : question['translation']!,
                      style: GoogleFonts.poppins(
                        fontSize: size.width * 0.1,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: size.height * 0.05),
                    ...options.map((option) => Padding(
                      padding: EdgeInsets.symmetric(vertical: size.height * 0.01),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(size.width * 0.03),
                          border: Border.all(
                            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                            width: size.width * 0.005,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(size.width * 0.03),
                            onTap: () => _checkAnswer(option),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.015),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: GoogleFonts.poppins(
                                        fontSize: size.width * 0.045,
                                        color: isDarkMode ? Colors.white70 : Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.volume_up_rounded,
                                      color: const Color(0xFF2196F3),
                                      size: size.width * 0.05,
                                    ),
                                    onPressed: () => _voiceService.speak(option, widget.selectedLanguage),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )).toList(),
                  ],
                ),
              ).animate().fadeIn(
                duration: 600.ms,
              ).slideY(
                begin: 0.2,
                end: 0,
                duration: 600.ms,
                curve: Curves.easeOut,
              ),
            ),
            if (_assessmentIndex >= 4)
              Padding(
                padding: EdgeInsets.only(top: size.height * 0.025),
                child: TextButton(
                  onPressed: _endAssessment,
                  child: Text(
                    "Opt Out",
                    style: GoogleFonts.poppins(
                      fontSize: size.width * 0.04,
                      color: isDarkMode ? Colors.white70 : const Color(0xFF2196F3),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _generateOptions(String correctAnswer) {
    final options = [correctAnswer];
    final otherItems = _content
        .where((item) =>
    (_selectedOption == "alphabets" ? item['pronunciation'] : item['text']) != correctAnswer)
        .toList();
    otherItems.shuffle();
    options.addAll(otherItems
        .take(2)
        .map((item) => _selectedOption == "alphabets" ? item['pronunciation']! : item['text']!));
    options.shuffle();
    return options;
  }
}