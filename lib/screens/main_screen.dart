import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../database/db_helper.dart';
import '../providers/theme_provider.dart';
import 'learning_screen.dart';
import 'login_page.dart';

class MainScreen extends StatefulWidget {
  final String userEmail;

  const MainScreen({required this.userEmail, Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String username = "Loading...";
  String email = "Loading...";
  int streak = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = await DatabaseHelper.instance.getUserByEmail(widget.userEmail);

    if (user != null && mounted) {
      setState(() {
        username = user['username'];
        email = user['email'];
        streak = user['streak'] ?? 0;
      });
    } else {
      setState(() {
        username = "Unknown User";
        email = widget.userEmail;
        streak = 0;
      });
      print("❌ No user found for email: ${widget.userEmail}");
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
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: size.width * 0.06, vertical: size.height * 0.04),
                child: Container(
                  padding: EdgeInsets.all(size.width * 0.06),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(size.width * 0.06),
                    border: Border.all(
                      color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: size.width * 0.4,
                        height: size.width * 0.4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(size.width * 0.04),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(size.width * 0.04),
                          child: Image.asset(
                            'assets/echo_main.gif',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.error,
                              size: size.width * 0.12,
                              color: isDarkMode ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 800.ms).scale(),
                      SizedBox(height: size.height * 0.03),
                      Text(
                        'Welcome Back, $username!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: size.width * 0.07,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white70 : const Color(0xFF2196F3),
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                      SizedBox(height: size.height * 0.02),
                      Text(
                        'Let’s continue your learning journey!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: size.width * 0.04,
                          color: theme.textTheme.bodyMedium?.color ?? Colors.grey[600],
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
                      SizedBox(height: size.height * 0.06),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              text: 'Start Learning',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LearningScreen(userEmail: widget.userEmail),
                                ),
                              ),
                              color: const Color(0xFF2196F3),
                              size: size,
                            ),
                          ),
                          SizedBox(width: size.width * 0.04),
                          Expanded(
                            child: _buildActionButton(
                              text: 'Sign Out',
                              onPressed: () => _showLogoutDialog(context),
                              color: Colors.redAccent,
                              size: size,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 300.ms, delay: 600.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
    required Color color,
    required Size size,
  }) {
    return SizedBox(
      height: size.height * 0.06,
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {});
        },
        onTapUp: (_) {
          setState(() {});
          onPressed();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(size.width * 0.03),
          ),
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: size.width * 0.04,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ).animate().scale(duration: 200.ms);
  }

  void _showLogoutDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final size = MediaQuery.of(context).size;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.width * 0.06)),
        child: Padding(
          padding: EdgeInsets.all(size.width * 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.logout_rounded,
                size: size.width * 0.12,
                color: Colors.redAccent,
              ),
              SizedBox(height: size.height * 0.02),
              Text(
                "Sign Out?",
                style: GoogleFonts.poppins(
                  fontSize: size.width * 0.05,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                ),
              ),
              SizedBox(height: size.height * 0.02),
              Text(
                "Are you sure you want to sign out?",
                style: GoogleFonts.poppins(
                  fontSize: size.width * 0.035,
                  color: theme.textTheme.bodyMedium?.color ?? Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: size.height * 0.03),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.textTheme.bodyMedium?.color ?? Colors.grey[600],
                        padding: EdgeInsets.symmetric(vertical: size.height * 0.02),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.width * 0.03)),
                      ),
                      child: Text(
                        "Cancel",
                        style: GoogleFonts.poppins(
                          fontSize: size.width * 0.035,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyMedium?.color ?? Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: size.width * 0.04),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: size.height * 0.02),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.width * 0.03)),
                        elevation: 0,
                      ),
                      child: Text(
                        "Sign Out",
                        style: GoogleFonts.poppins(
                          fontSize: size.width * 0.035,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}