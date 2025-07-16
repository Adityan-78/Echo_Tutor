import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../database/db_helper.dart';
import '../providers/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  final String userEmail;

  const ProfileScreen({required this.userEmail, Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _ageController;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _ageController = TextEditingController();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = await DatabaseHelper.instance.getUserByEmail(widget.userEmail);
    if (user != null) {
      setState(() {
        _userData = user;
        _fullNameController.text = user['full_name'] ?? '';
        _ageController.text = user['age']?.toString() ?? '';
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "User not found!",
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _updateUserData() async {
    if (_formKey.currentState!.validate()) {
      await DatabaseHelper.instance.updateUserDetails(
        widget.userEmail,
        _fullNameController.text,
        int.tryParse(_ageController.text) ?? 0,
      );
      setState(() {
        _isEditing = false;
        _userData!['full_name'] = _fullNameController.text;
        _userData!['age'] = int.tryParse(_ageController.text) ?? 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Profile updated successfully!",
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    super.dispose();
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
            _isLoading
                ? Center(
              child: CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation(Color(0xFF2196F3)),
              ).animate().scale(),
            )
                : SingleChildScrollView(
              child: Column(
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
                          "Profile",
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
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.03),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileField(
                            label: "Username",
                            value: _userData!['username'] ?? 'N/A',
                            isEditable: false,
                            size: size,
                          ),
                          SizedBox(height: size.height * 0.02),
                          _buildProfileField(
                            label: "Email",
                            value: _userData!['email'] ?? 'N/A',
                            isEditable: false,
                            size: size,
                          ),
                          SizedBox(height: size.height * 0.02),
                          _buildProfileField(
                            label: "Full Name",
                            controller: _fullNameController,
                            isEditable: _isEditing,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                            size: size,
                          ),
                          SizedBox(height: size.height * 0.02),
                          _buildProfileField(
                            label: "Age",
                            controller: _ageController,
                            isEditable: _isEditing,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your age';
                              }
                              if (int.tryParse(value) == null || int.parse(value) <= 0) {
                                return 'Please enter a valid age';
                              }
                              return null;
                            },
                            size: size,
                          ),
                          SizedBox(height: size.height * 0.03),
                          Center(
                            child: ElevatedButton(
                              onPressed: () {
                                if (_isEditing) {
                                  _updateUserData();
                                } else {
                                  setState(() => _isEditing = true);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2196F3),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: size.width * 0.08,
                                  vertical: size.height * 0.015,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(size.width * 0.03),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                _isEditing ? "Save" : "Edit Profile",
                                style: GoogleFonts.poppins(
                                  fontSize: size.width * 0.04,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ).animate().fadeIn(duration: 600.ms).slideY(
                              begin: 0.2,
                              duration: 600.ms,
                              curve: Curves.easeOut,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField({
    required String label,
    String? value,
    TextEditingController? controller,
    bool isEditable = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    required Size size,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: size.width * 0.04,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        SizedBox(height: size.height * 0.01),
        Container(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.015),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(size.width * 0.03),
          ),
          child: isEditable
              ? TextFormField(
            controller: controller,
            style: GoogleFonts.poppins(
              color: isDarkMode ? Colors.white70 : Colors.black87,
              fontSize: size.width * 0.035,
            ),
            keyboardType: keyboardType,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Enter $label',
              hintStyle: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white54 : Colors.grey[400],
                fontSize: size.width * 0.035,
              ),
            ),
            validator: validator,
          )
              : Text(
            value ?? '',
            style: GoogleFonts.poppins(
              color: isDarkMode ? Colors.white70 : Colors.black87,
              fontSize: size.width * 0.035,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(
      begin: 0.2,
      duration: 600.ms,
      curve: Curves.easeOut,
    );
  }
}