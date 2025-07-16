import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../database/db_helper.dart';
import '../providers/theme_provider.dart';
import 'login_page.dart';
import 'profile_screen.dart';

class MenuScreen extends StatelessWidget {
  final String userEmail;

  const MenuScreen({required this.userEmail, Key? key}) : super(key: key);

  Future<void> _logout(BuildContext context) async {
    await DatabaseHelper.instance.updateUserStreak(userEmail, 0);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
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
                        "Menu",
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
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.person,
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                          size: size.width * 0.06,
                        ),
                        title: Text(
                          "Profile",
                          style: GoogleFonts.poppins(
                            color: isDarkMode ? Colors.white70 : Colors.black87,
                            fontSize: size.width * 0.04,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(userEmail: userEmail),
                            ),
                          );
                        },
                      ).animate().fadeIn(duration: 600.ms).slideY(
                        begin: 0.2,
                        duration: 600.ms,
                        curve: Curves.easeOut,
                      ),
                      ListTile(
                        leading: Icon(
                          isDarkMode ? Icons.dark_mode : Icons.light_mode,
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                          size: size.width * 0.06,
                        ),
                        title: Text(
                          "Theme",
                          style: GoogleFonts.poppins(
                            color: isDarkMode ? Colors.white70 : Colors.black87,
                            fontSize: size.width * 0.04,
                          ),
                        ),
                        trailing: Switch(
                          value: isDarkMode,
                          onChanged: (value) {
                            themeProvider.toggleTheme();
                          },
                          activeColor: const Color(0xFF2196F3),
                        ),
                      ).animate().fadeIn(duration: 600.ms).slideY(
                        begin: 0.2,
                        duration: 600.ms,
                        curve: Curves.easeOut,
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.logout,
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                          size: size.width * 0.06,
                        ),
                        title: Text(
                          "Logout",
                          style: GoogleFonts.poppins(
                            color: isDarkMode ? Colors.white70 : Colors.black87,
                            fontSize: size.width * 0.04,
                          ),
                        ),
                        onTap: () => _logout(context),
                      ).animate().fadeIn(duration: 600.ms).slideY(
                        begin: 0.2,
                        duration: 600.ms,
                        curve: Curves.easeOut,
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
}