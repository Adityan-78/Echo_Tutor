import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  String _userEmail = '';

  bool get isDarkMode => _isDarkMode;

  ThemeProvider(String email) {
    _userEmail = email;
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final theme = await DatabaseHelper.instance.getThemePreference(_userEmail);
    _isDarkMode = theme == 'dark';
    notifyListeners();
  }
  void updateEmail(String email) {
    _userEmail = email;
    _loadTheme();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await DatabaseHelper.instance.updateThemePreference(_userEmail, _isDarkMode ? 'dark' : 'light');
    notifyListeners();
  }

  ThemeData getTheme() {
    return _isDarkMode ? darkTheme : lightTheme;
  }
}

final lightTheme = ThemeData(
  primaryColor: Colors.white,
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    elevation: 0,
    iconTheme: IconThemeData(color: Colors.black),
    titleTextStyle: TextStyle(color: Colors.black),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.black87),
    bodyMedium: TextStyle(color: Colors.black54),
  ),
  cardColor: Colors.white,
  iconTheme: const IconThemeData(color: Colors.black),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: Color(0xFF2196F3),
    unselectedItemColor: Colors.grey,
  ),
);

final darkTheme = ThemeData(
  primaryColor: Colors.black,
  scaffoldBackgroundColor: const Color(0xFF121212),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E1E1E),
    elevation: 0,
    iconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(color: Colors.white),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white70),
    bodyMedium: TextStyle(color: Colors.white54),
  ),
  cardColor: const Color(0xFF1E1E1E),
  iconTheme: const IconThemeData(color: Colors.white),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFF1E1E1E),
    selectedItemColor: Color(0xFF2196F3),
    unselectedItemColor: Colors.grey,
  ),
);