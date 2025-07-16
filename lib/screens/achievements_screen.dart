import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../database/db_helper.dart';
import '../services/gemini_achievement_generator.dart';
import 'basics_screen.dart';
import 'lesson_screen.dart';
import 'pronounce_screen.dart';
import 'quiz_screen.dart';
import 'translate_screen.dart';
import '../providers/theme_provider.dart';

class AchievementsScreen extends StatefulWidget {
  final String userEmail;
  final String selectedLanguage;

  const AchievementsScreen({
    required this.userEmail,
    required this.selectedLanguage,
    Key? key,
  }) : super(key: key);

  @override
  _AchievementsScreenState createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _userStreak = 0;
  int _userXP = 0;
  int _userLevel = 0;
  int _totalLearningTime = 0;
  int _totalQuizTime = 0;
  int _lessonsCompleted = 0;
  int _translationsPerformed = 0;
  List<Map<String, dynamic>> _dailyAchievements = [];
  List<Map<String, dynamic>> _overallAchievements = [];
  DateTime? _lastDailyRefresh;
  final _geminiGenerator = GeminiAchievementGenerator();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
    _loadAchievements();
  }

  Future<void> _loadUserData() async {
    final user = await DatabaseHelper.instance.getUserByEmail(widget.userEmail);
    if (user != null && mounted) {
      setState(() {
        _userStreak = user['streak'] ?? 0;
        _userXP = user['xp'] ?? 0;
        _userLevel = _calculateLevel(_userXP);
        _totalLearningTime = user['total_learning_time'] ?? 0;
        _totalQuizTime = user['total_quiz_time'] ?? 0;
        _lessonsCompleted = user['lessons_completed'] ?? 0;
        _translationsPerformed = user['translations_performed'] ?? 0;
      });
    }
  }

  int _calculateLevel(int xp) {
    final thresholds = [150, 400, 800, 1350, 2050];
    for (int i = 0; i < thresholds.length; i++) {
      if (xp < thresholds[i]) return i + 1;
    }
    return thresholds.length + 1;
  }

  Future<void> _loadAchievements() async {
    if (_overallAchievements.isEmpty) {
      final hardcodedAchievements = [
        {
          'achievement_id': 'login_streak_5',
          'title': 'Learner I',
          'description': 'Log in consecutively for 5 days to maintain a consistent learning streak.',
          'goal': 5,
          'xp_reward': 50,
          'progress': _userStreak,
        },
        {
          'achievement_id': 'login_streak_10',
          'title': 'Learner II',
          'description': 'Log in consecutively for 10 days to show dedication to learning.',
          'goal': 10,
          'xp_reward': 100,
          'progress': _userStreak,
        },
        {
          'achievement_id': 'login_streak_50',
          'title': 'Learner III',
          'description': 'Log in consecutively for 50 days to become a true learning champion.',
          'goal': 50,
          'xp_reward': 500,
          'progress': _userStreak,
        },
        {
          'achievement_id': 'learning_time_60',
          'title': 'Scholar I',
          'description': 'Spend 1 hour learning to build a strong foundation in your chosen language.',
          'goal': 60,
          'xp_reward': 50,
          'progress': _totalLearningTime,
        },
        {
          'achievement_id': 'learning_time_300',
          'title': 'Scholar II',
          'description': 'Spend 5 hours learning to deepen your language knowledge.',
          'goal': 300,
          'xp_reward': 150,
          'progress': _totalLearningTime,
        },
        {
          'achievement_id': 'learning_time_1200',
          'title': 'Scholar III',
          'description': 'Spend 20 hours learning to achieve mastery in your language studies.',
          'goal': 1200,
          'xp_reward': 300,
          'progress': _totalLearningTime,
        },
        {
          'achievement_id': 'quiz_time_30',
          'title': 'Quiz Novice I',
          'description': 'Spend 30 minutes in quizzes to test your language skills.',
          'goal': 30,
          'xp_reward': 50,
          'progress': _totalQuizTime,
        },
        {
          'achievement_id': 'quiz_time_120',
          'title': 'Quiz Novice II',
          'description': 'Spend 2 hours in quizzes to strengthen your knowledge.',
          'goal': 120,
          'xp_reward': 100,
          'progress': _totalQuizTime,
        },
        {
          'achievement_id': 'quiz_time_600',
          'title': 'Quiz Master',
          'description': 'Spend 10 hours in quizzes to become a quiz expert.',
          'goal': 600,
          'xp_reward': 200,
          'progress': _totalQuizTime,
        },
        {
          'achievement_id': 'lessons_5',
          'title': 'Lesson Explorer I',
          'description': 'Complete 5 lessons to start your language learning journey.',
          'goal': 5,
          'xp_reward': 50,
          'progress': _lessonsCompleted,
        },
        {
          'achievement_id': 'lessons_20',
          'title': 'Lesson Explorer II',
          'description': 'Complete 20 lessons to advance your language skills.',
          'goal': 20,
          'xp_reward': 150,
          'progress': _lessonsCompleted,
        },
        {
          'achievement_id': 'lessons_50',
          'title': 'Lesson Master',
          'description': 'Complete 50 lessons to master key language concepts.',
          'goal': 50,
          'xp_reward': 300,
          'progress': _lessonsCompleted,
        },
        {
          'achievement_id': 'translations_10',
          'title': 'Translator I',
          'description': 'Perform 10 translations to practice real-world language use.',
          'goal': 10,
          'xp_reward': 50,
          'progress': _translationsPerformed,
        },
        {
          'achievement_id': 'translations_50',
          'title': 'Translator II',
          'description': 'Perform 50 translations to improve your translation skills.',
          'goal': 50,
          'xp_reward': 150,
          'progress': _translationsPerformed,
        },
        {
          'achievement_id': 'translations_100',
          'title': 'Translation Expert',
          'description': 'Perform 100 translations to become a translation expert.',
          'goal': 100,
          'xp_reward': 300,
          'progress': _translationsPerformed,
        },
        {
          'achievement_id': 'xp_500',
          'title': 'XP Collector I',
          'description': 'Earn 500 XP to show your progress in language learning.',
          'goal': 500,
          'xp_reward': 50,
          'progress': _userXP,
        },
        {
          'achievement_id': 'xp_1000',
          'title': 'XP Collector II',
          'description': 'Earn 1000 XP to demonstrate your commitment to learning.',
          'goal': 1000,
          'xp_reward': 100,
          'progress': _userXP,
        },
        {
          'achievement_id': 'xp_5000',
          'title': 'XP Master',
          'description': 'Earn 5000 XP to become an XP master in language learning.',
          'goal': 5000,
          'xp_reward': 500,
          'progress': _userXP,
        },
        {
          'achievement_id': 'level_3',
          'title': 'Rising Star I',
          'description': 'Reach Level 3 by earning XP through various activities.',
          'goal': 3,
          'xp_reward': 100,
          'progress': _userLevel,
        },
        {
          'achievement_id': 'level_5',
          'title': 'Rising Star II',
          'description': 'Reach Level 5 by accumulating XP and advancing your skills.',
          'goal': 5,
          'xp_reward': 200,
          'progress': _userLevel,
        },
      ];

      for (var achievement in hardcodedAchievements) {
        await DatabaseHelper.instance.insertAchievement(
          userEmail: widget.userEmail,
          achievementId: achievement['achievement_id'].toString(),
          title: achievement['title'].toString(),
          goal: achievement['goal'] as int,
          xpReward: achievement['xp_reward'] as int,
          type: 'hardcoded',
        );

        await DatabaseHelper.instance.updateAchievementProgress(
          widget.userEmail,
          achievement['achievement_id'].toString(),
          achievement['progress'] as int,
        );
      }

      final dbAchievements = await DatabaseHelper.instance.getAchievements(widget.userEmail, 'hardcoded');
      if (mounted) {
        setState(() {
          _overallAchievements = dbAchievements;
        });
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _lastDailyRefresh ??= today.subtract(const Duration(days: 1));

    if (today.difference(_lastDailyRefresh!).inDays >= 1 || _dailyAchievements.isEmpty) {
      final dailyAchievements = await _geminiGenerator.generateDailyAchievements(widget.selectedLanguage);
      for (var achievement in dailyAchievements) {
        final goal = _parseGoalFromDescription(achievement['description']?.toString() ?? '1');
        await DatabaseHelper.instance.insertAchievement(
          userEmail: widget.userEmail,
          achievementId: '${achievement['title']}_${DateTime.now().toIso8601String()}',
          title: achievement['title']?.toString() ?? 'Untitled',
          goal: goal,
          xpReward: 30,
          type: 'gemini',
        );
      }
      final dbDailyAchievements = await DatabaseHelper.instance.getAchievements(widget.userEmail, 'gemini');
      if (mounted) {
        setState(() {
          _dailyAchievements = dbDailyAchievements;
          _lastDailyRefresh = today;
        });
      }
    }
  }

  int _parseGoalFromDescription(String description) {
    final regex = RegExp(r'(\d+)');
    final match = regex.firstMatch(description);
    return match != null ? int.parse(match.group(0)!) : 1;
  }

  IconData _getIconForAction(String? action) {
    switch (action) {
      case "lesson":
        return Icons.book;
      case "pronunciation":
        return Icons.mic;
      case "quiz":
        return Icons.quiz;
      case "translate":
        return Icons.translate;
      default:
        return Icons.star;
    }
  }

  VoidCallback? _getActionForAchievement(String? action, String language) {
    switch (action) {
      case "lesson":
        return () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => LessonScreen(selectedLanguage: language)),
          );
        };
      case "pronunciation":
        return () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PronounceScreen(selectedLanguage: language)),
          );
        };
      case "quiz":
        return () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => QuizScreen(selectedLanguage: language, userEmail: widget.userEmail)),
          );
        };
      case "translate":
        return () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TranslateScreen()),
          );
        };
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final size = MediaQuery.of(context).size;

    return Scaffold(
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
                        "Achievements",
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
                TabBar(
                  controller: _tabController,
                  labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: size.width * 0.04),
                  unselectedLabelStyle: GoogleFonts.poppins(fontSize: size.width * 0.04),
                  labelColor: const Color(0xFF2196F3),
                  unselectedLabelColor: isDarkMode ? Colors.white54 : Colors.grey[600],
                  indicatorColor: const Color(0xFF2196F3),
                  tabs: const [
                    Tab(text: "Overall"),
                    Tab(text: "Daily"),
                  ],
                ).animate().fadeIn(duration: 600.ms).slideY(
                  begin: 0.2,
                  duration: 600.ms,
                  curve: Curves.easeOut,
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      SingleChildScrollView(
                        padding: EdgeInsets.all(size.width * 0.04),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Overall Progress",
                              style: GoogleFonts.poppins(
                                fontSize: size.width * 0.045,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white70 : Colors.black87,
                              ),
                            ).animate().fadeIn(duration: 600.ms).slideY(
                              begin: 0.2,
                              duration: 600.ms,
                              curve: Curves.easeOut,
                            ),
                            SizedBox(height: size.height * 0.015),
                            _buildAchievementItem("Level $_userLevel Reached", Icons.star, _userLevel > 1, size),
                            _buildAchievementItem("$_userStreak Day Streak", Icons.local_fire_department, _userStreak > 0, size),
                            _buildAchievementItem("$_userXP XP Earned", Icons.score, _userXP > 0, size),
                            SizedBox(height: size.height * 0.02),
                            Text(
                              "Achievements",
                              style: GoogleFonts.poppins(
                                fontSize: size.width * 0.045,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white70 : Colors.black87,
                              ),
                            ).animate().fadeIn(duration: 600.ms).slideY(
                              begin: 0.2,
                              duration: 600.ms,
                              curve: Curves.easeOut,
                            ),
                            SizedBox(height: size.height * 0.015),
                            ..._overallAchievements.map((achievement) => _buildAchievementCard(achievement, size)).toList(),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        padding: EdgeInsets.all(size.width * 0.04),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Daily Goals",
                              style: GoogleFonts.poppins(
                                fontSize: size.width * 0.045,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white70 : Colors.black87,
                              ),
                            ).animate().fadeIn(duration: 600.ms).slideY(
                              begin: 0.2,
                              duration: 600.ms,
                              curve: Curves.easeOut,
                            ),
                            SizedBox(height: size.height * 0.015),
                            ..._dailyAchievements.map((achievement) => _buildAchievementCard(achievement, size)).toList(),
                          ],
                        ),
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

  Widget _buildAchievementItem(String title, IconData icon, bool achieved, Size size) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return ListTile(
      leading: Icon(
        icon,
        color: achieved ? const Color(0xFF2196F3) : (isDarkMode ? Colors.grey[600] : Colors.grey[400]),
        size: size.width * 0.06,
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: achieved ? (isDarkMode ? Colors.white70 : Colors.black87) : (isDarkMode ? Colors.white54 : Colors.grey[600]),
          fontSize: size.width * 0.04,
        ),
      ),
      trailing: Icon(
        achieved ? Icons.check_circle : Icons.circle_outlined,
        color: achieved ? const Color(0xFF2196F3) : (isDarkMode ? Colors.grey[600] : Colors.grey[400]),
        size: size.width * 0.06,
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(
      begin: 0.2,
      duration: 600.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildAchievementCard(Map<String, dynamic> achievement, Size size) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final language = widget.selectedLanguage;
    final action = achievement['type'] == 'gemini' ? achievement['action']?.toString() : null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.width * 0.03)),
      color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
      child: ListTile(
        leading: Icon(
          _getIconForAction(action),
          color: (achievement['completed'] == 1) ? const Color(0xFF2196F3) : (isDarkMode ? Colors.white54 : Colors.grey[600]),
          size: size.width * 0.06,
        ),
        title: Text(
          achievement['title']?.toString() ?? 'Untitled',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: (achievement['completed'] == 1)
                ? (isDarkMode ? Colors.white70 : Colors.black87)
                : (isDarkMode ? Colors.white54 : Colors.grey[600]),
            fontSize: size.width * 0.04,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              achievement['type'] == 'hardcoded'
                  ? (achievement['description']?.toString() ?? 'No description')
                  : 'Progress: ${achievement['progress']?.toString() ?? '0'}/${achievement['goal']?.toString() ?? '1'}',
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white54 : Colors.black54,
                fontSize: size.width * 0.035,
              ),
            ),
            if (achievement['completed'] == 1)
              Text(
                'XP Earned: ${achievement['xp_reward']?.toString() ?? '0'}',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF2196F3),
                  fontSize: size.width * 0.03,
                ),
              ),
          ],
        ),
        trailing: action != null
            ? ElevatedButton(
          onPressed: _getActionForAchievement(action, language),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.width * 0.02)),
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.03, vertical: size.height * 0.01),
          ),
          child: Text(
            "Start",
            style: GoogleFonts.poppins(color: Colors.white, fontSize: size.width * 0.035),
          ),
        )
            : Icon(
          (achievement['completed'] == 1) ? Icons.check_circle : Icons.circle_outlined,
          color: (achievement['completed'] == 1)
              ? const Color(0xFF2196F3)
              : (isDarkMode ? Colors.grey[600] : Colors.grey[400]),
          size: size.width * 0.06,
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(
      begin: 0.2,
      duration: 600.ms,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}