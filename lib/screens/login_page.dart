import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../database/db_helper.dart';
import '../providers/theme_provider.dart';
import 'main_screen.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("Please fill in all fields");
      setState(() => _isLoading = false);
      return;
    }

    try {
      final user = await DatabaseHelper.instance.getUser(email, password);

      if (user != null) {
        Provider.of<ThemeProvider>(context, listen: false).updateEmail(email);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainScreen(userEmail: email)),
        );
      } else {
        _showSnackBar("Invalid email or password");
      }
    } catch (e) {
      _showSnackBar("Login error: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: size.width * 0.4,
                      height: size.width * 0.4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(size.width * 0.03),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(size.width * 0.03),
                        child: Image.asset(
                          'assets/main_echo.gif',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.error,
                            size: size.width * 0.12,
                            color: isDarkMode ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 600.ms).scale(),
                    SizedBox(height: size.height * 0.03),
                    Text(
                      'Welcome Back',
                      style: GoogleFonts.poppins(
                        fontSize: size.width * 0.07,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                      ),
                    ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                    SizedBox(height: size.height * 0.04),
                    _buildInputField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      size: size,
                    ),
                    SizedBox(height: size.height * 0.02),
                    _buildPasswordField(size),
                    SizedBox(height: size.height * 0.02),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          _showSnackBar("Forgot password feature coming soon!");
                        },
                        child: Text(
                          'Forgot password?',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF2196F3),
                            fontSize: size.width * 0.035,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: size.height * 0.03),
                    _isLoading
                        ? CircularProgressIndicator(
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF2196F3)),
                    ).animate().scale()
                        : _buildAuthButton(
                      text: 'Sign In',
                      onPressed: _login,
                      size: size,
                    ),
                    SizedBox(height: size.height * 0.02),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: GoogleFonts.poppins(
                            color: theme.textTheme.bodyMedium?.color ?? Colors.grey[600],
                            fontSize: size.width * 0.035,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => RegisterPage()),
                          ),
                          child: Text(
                            'Sign up',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF2196F3),
                              fontSize: size.width * 0.035,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 200.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required Size size,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: isDarkMode ? Colors.white54 : Colors.grey[600],
          fontSize: size.width * 0.035,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF2196F3), size: size.width * 0.05),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(size.width * 0.03),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(size.width * 0.03),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(size.width * 0.03),
          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
        ),
      ),
      style: GoogleFonts.poppins(
        color: isDarkMode ? Colors.white70 : Colors.black87,
        fontSize: size.width * 0.035,
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildPasswordField(Size size) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: GoogleFonts.poppins(
          color: isDarkMode ? Colors.white54 : Colors.grey[600],
          fontSize: size.width * 0.035,
        ),
        prefixIcon: Icon(Icons.lock_outline, color: const Color(0xFF2196F3), size: size.width * 0.05),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: isDarkMode ? Colors.white54 : Colors.grey[600],
            size: size.width * 0.05,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(size.width * 0.03),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(size.width * 0.03),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(size.width * 0.03),
          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
        ),
      ),
      style: GoogleFonts.poppins(
        color: isDarkMode ? Colors.white70 : Colors.black87,
        fontSize: size.width * 0.035,
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 100.ms);
  }

  Widget _buildAuthButton({
    required String text,
    required VoidCallback onPressed,
    required Size size,
  }) {
    return SizedBox(
      width: double.infinity,
      height: size.height * 0.06,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.width * 0.03)),
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.1),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: size.width * 0.04,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 200.ms);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}