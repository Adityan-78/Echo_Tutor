import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/voice_service.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final String language;
  final VoiceService voiceService;

  const ChatBubble({
    required this.text,
    required this.isUser,
    required this.language,
    required this.voiceService,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: size.height * 0.008),
        constraints: BoxConstraints(maxWidth: size.width * 0.75),
        child: Card(
          elevation: 0,
          color: isUser ? const Color(0xFF2196F3) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.width * 0.04)),
          shadowColor: Colors.black.withOpacity(0.1),
          child: Padding(
            padding: EdgeInsets.all(size.width * 0.03),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        style: GoogleFonts.poppins(
                          fontSize: size.width * 0.035,
                          color: isUser ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    if (!isUser)
                      IconButton(
                        icon: Icon(Icons.volume_up, size: size.width * 0.05, color: const Color(0xFF2196F3)),
                        onPressed: () => voiceService.speak(text, language),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Listen',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ).animate().slideX(
        begin: isUser ? 0.5 : -0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      ),
    );
  }
}

class VoiceInputField extends StatefulWidget {
  final Function(String) onMessageSent;
  final VoiceService voiceService;
  final String language;

  const VoiceInputField({
    required this.onMessageSent,
    required this.voiceService,
    required this.language,
    Key? key,
  }) : super(key: key);

  @override
  _VoiceInputFieldState createState() => _VoiceInputFieldState();
}

class _VoiceInputFieldState extends State<VoiceInputField> {
  final TextEditingController _controller = TextEditingController();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(size.width * 0.03),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: size.width * 0.02,
                    offset: Offset(0, size.height * 0.005),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: "Type or speak...",
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: size.width * 0.035,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(size.width * 0.03),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.015),
                ),
                style: GoogleFonts.poppins(
                  fontSize: size.width * 0.035,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          SizedBox(width: size.width * 0.02),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2196F3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: size.width * 0.02,
                  offset: Offset(0, size.height * 0.005),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                Icons.send,
                color: Colors.white,
                size: size.width * 0.05,
              ),
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  widget.onMessageSent(_controller.text);
                  _controller.clear();
                }
              },
              padding: EdgeInsets.all(size.width * 0.03),
              tooltip: 'Send',
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}