import 'package:echo/screens/pronounce_screen.dart';
import 'package:echo/screens/translate_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:math'; // Added for calculations
import '../database/db_helper.dart';
import 'basics_screen.dart';
import 'chat_screen.dart';
import 'lesson_screen.dart';
import 'quiz_screen.dart';
import 'achievements_screen.dart';
import 'menu_screen.dart';
import '../providers/theme_provider.dart';

class LearningScreen extends StatefulWidget {
  final String userEmail;

  const LearningScreen({required this.userEmail, Key? key}) : super(key: key);

  @override
  _LearningScreenState createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  String _selectedLanguage = 'English';
  int _userStreak = 0;
  int _userXP = 0;
  int _userLevel = 0;
  String _userName = 'User';

  final List<String> _languages = [
    'English', 'German', 'Hindi', 'Spanish',
    'French', 'Arabic', 'Korean', 'Russian',
    'Italian', 'Portuguese', 'Japanese', 'Chinese',
    'Tamil', 'Telugu', 'Malayalam'
  ];

  final List<Map<String, dynamic>> _features = [
    {
      "label": "Basics",
      "lightColor": const Color(0xFFD1FAE5),
      "darkColor": const Color(0xFF2A6A4A),
      "progress": 0.0,
      "type": "Article",
      "duration": "30 min",
      "height": 150.0,
      "isFullWidth": false,
    },
    {
      "label": "Say It Right",
      "lightColor": const Color(0xFFEDE9FE),
      "darkColor": const Color(0xFF4B3A6F),
      "progress": 0.0,
      "type": "Practice",
      "duration": "15 min",
      "height": 150.0,
      "isFullWidth": false,
    },
    {
      "label": "WordCheck",
      "lightColor": const Color(0xFFFFF7D4),
      "darkColor": const Color(0xFF6B5E2A),
      "progress": 0.0,
      "type": "Article",
      "duration": "20 min",
      "height": 100.0,
      "isFullWidth": true,
    },
    {
      "label": "Translate",
      "lightColor": const Color(0xFFFEE2E2),
      "darkColor": const Color(0xFF6A3A3A),
      "progress": 0.0,
      "type": "Tool",
      "duration": "",
      "height": 150.0,
      "isFullWidth": false,
    },
    {
      "label": "Quiz",
      "lightColor": const Color(0xFFE0F2FE),
      "darkColor": const Color(0xFF3A5A6A),
      "progress": 0.0,
      "type": "Quiz",
      "duration": "10 min",
      "height": 150.0,
      "isFullWidth": false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await DatabaseHelper.instance.getUserByEmail(widget.userEmail);
    if (user != null) {
      setState(() {
        _userName = user['username'] ?? 'User';
        _userStreak = user['streak'] ?? 0;
        _userXP = user['xp'] ?? 0;
        _userLevel = _calculateLevel(_userXP);
      });
      print("✅ Fetched user: $_userName, Streak: $_userStreak, XP: $_userXP");
    } else {
      print("❌ No user found for email: ${widget.userEmail}");
      setState(() {
        _userName = 'User';
        _userStreak = 0;
        _userXP = 0;
        _userLevel = 0;
      });
    }
  }

  int _calculateLevel(int xp) {
    final thresholds = [150, 400, 800, 1350, 2050];
    for (int i = 0; i < thresholds.length; i++) {
      if (xp < thresholds[i]) return i;
    }
    return thresholds.length;
  }

  int _getNextLevelXP(int level) {
    final thresholds = [150, 400, 800, 1350, 2050];
    return level < thresholds.length ? thresholds[level] : thresholds.last;
  }

  Future<void> _startQuiz() async {
    final xpEarned = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          selectedLanguage: _selectedLanguage,
          userEmail: widget.userEmail,
        ),
      ),
    );
    if (xpEarned != null) {
      final int xp = xpEarned as int;
      setState(() {
        _userXP += xp;
        _userLevel = _calculateLevel(_userXP);
      });
      await DatabaseHelper.instance.updateUserXp(widget.userEmail, xp);
      if (_userXP >= _getNextLevelXP(_userLevel)) {
        _showLevelUpDialog();
      }
    }
  }

  void _showLevelUpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          "Level Up!",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        content: Text(
          "Congratulations! You've reached Level $_userLevel and earned a badge!",
          style: GoogleFonts.poppins(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Awesome!",
              style: GoogleFonts.poppins(color: const Color(0xFF2196F3)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation,
        title: Row(
          children: [
            Text(
              "Hi, $_userName",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color ?? Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF4A3D1A) : const Color(0xFFFFF7D4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: Colors.orange[800],
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "$_userStreak",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            CircleAvatar(
              radius: 20,
              backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[200],
              child: Icon(
                Icons.person,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
        iconTheme: theme.iconTheme,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // XP Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Level $_userLevel",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                        ),
                      ),
                      Text(
                        "$_userXP / ${_getNextLevelXP(_userLevel)} XP",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color ?? Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _userXP / _getNextLevelXP(_userLevel),
                      backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF2196F3)),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2A3A4A) : const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "What would you like to learn today?",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedLanguage,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: _languages.map((lang) => DropdownMenuItem(
                              value: lang,
                              child: Text(
                                lang,
                                style: GoogleFonts.poppins(
                                  color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                                ),
                              ),
                            )).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedLanguage = val!;
                              });
                            },
                            dropdownColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Image.network(
                      'https://via.placeholder.com/120',
                      width: 120,
                      height: 120,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.school,
                        size: 60,
                        color: isDarkMode ? Colors.blue[300] : Colors.blue[800],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 12,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildFeatureCard(_features[0])),
                      const SizedBox(width: 8),
                      Expanded(child: _buildFeatureCard(_features[1])),
                    ],
                  ),
                  _buildFeatureCard(_features[2]), // Full-width card
                  Row(
                    children: [
                      Expanded(child: _buildFeatureCard(_features[3])),
                      const SizedBox(width: 8),
                      Expanded(child: _buildFeatureCard(_features[4])),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: "Achievements",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: "Quick Chat",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu),
            label: "Menu",
          ),
        ],
        selectedItemColor: const Color(0xFF2196F3),
        unselectedItemColor: theme.bottomNavigationBarTheme.unselectedItemColor ?? Colors.grey[600],
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        backgroundColor: theme.bottomNavigationBarTheme.backgroundColor ?? Colors.white,
        selectedLabelStyle: GoogleFonts.poppins(),
        unselectedLabelStyle: GoogleFonts.poppins(),
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AchievementsScreen(
                  userEmail: widget.userEmail,
                  selectedLanguage: _selectedLanguage,
                ),
              ),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  userEmail: widget.userEmail,
                  initialLanguage: _selectedLanguage,
                ),
              ),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MenuScreen(userEmail: widget.userEmail),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardColor = isDarkMode ? feature["darkColor"] as Color : feature["lightColor"] as Color;
    final isFullWidth = feature["isFullWidth"] as bool;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToFeature(feature),
        child: Container(
          height: feature["height"] as double,
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getIconForFeature(feature["label"] as String),
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      feature["label"] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${feature["type"]} ${feature["duration"].isNotEmpty ? '• ${feature["duration"]}' : ''}",
                      style: GoogleFonts.poppins(
                        color: isDarkMode ? Colors.white54 : Colors.black54,
                        fontSize: 11,
                      ),
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 300)).slideY(begin: 0.2, end: 0.0);
  }

  IconData _getIconForFeature(String label) {
    switch (label) {
      case "Basics":
        return Icons.school;
      case "WordCheck":
        return Icons.book;
      case "Say It Right":
        return Icons.mic;
      case "Translate":
        return Icons.translate;
      case "Quiz":
        return Icons.quiz;
      default:
        return Icons.star;
    }
  }

  void _navigateToFeature(Map<String, dynamic> feature) {
    if (feature["label"] == "WordCheck") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LessonScreen(selectedLanguage: _selectedLanguage),
        ),
      );
    } else if (feature["label"] == "Basics") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BasicsScreen(
            selectedLanguage: _selectedLanguage,
            userEmail: widget.userEmail,
          ),
        ),
      );
    } else if (feature["label"] == "Quiz") {
      _startQuiz();
    } else if (feature["label"] == "Translate") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TranslateScreen(),
        ),
      );
    } else if (feature["label"] == "Say It Right") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PronounceScreen(selectedLanguage: _selectedLanguage),
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}