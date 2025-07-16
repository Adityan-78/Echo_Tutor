import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:echo/database/db_helper.dart';
import 'package:echo/screens/login_page.dart';
import 'package:echo/screens/learning_screen.dart';
import 'package:echo/screens/menu_screen.dart';
import 'package:echo/screens/achievements_screen.dart';
import 'package:echo/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database before app starts
  await DatabaseHelper.instance.database;

  runApp(const EchoApp());
}

class EchoApp extends StatelessWidget {
  const EchoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provide ThemeProvider with an initial empty email (updated after login)
        ChangeNotifierProvider(
          create: (context) => ThemeProvider(''),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Echo',
            theme: themeProvider.getTheme(), // Apply the theme dynamically
            initialRoute: '/login',
            routes: {
              '/login': (context) => LoginPage(),
              '/learning': (context) => LearningScreen(
                userEmail: ModalRoute.of(context)!.settings.arguments as String,
              ),
              '/menu': (context) => MenuScreen(
                userEmail: ModalRoute.of(context)!.settings.arguments as String,
              ),
              '/achievements': (context) => AchievementsScreen(
                userEmail: ModalRoute.of(context)!.settings.arguments as String,
                selectedLanguage: ModalRoute.of(context)!.settings.arguments as String,
              ),
            },
          );
        },
      ),
    );
  }
}