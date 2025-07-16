import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/gemini_service.dart';
import '../providers/theme_provider.dart';

class ChatScreen extends StatefulWidget {
  final String userEmail;
  final String initialLanguage;

  const ChatScreen({
    required this.userEmail,
    required this.initialLanguage,
    Key? key,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String _selectedLanguage = '';
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();

  final List<String> _suggestions = [
    'Vocabulary',
    'Grammar',
    'Phrases',
    'Culture',
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
    _messages.add({
      'text': 'Hey there! I’m here to help you learn $_selectedLanguage. What would you like to learn today?',
      'isUser': false,
      'timestamp': DateTime.now(),
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        'text': text,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
    });
    _messageController.clear();
    _scrollToBottom();

    String response = await _geminiService.getChatResponse(text, _selectedLanguage);
    setState(() {
      _messages.add({
        'text': response,
        'isUser': false,
        'timestamp': DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addSuggestionMessage(String suggestion) {
    _sendMessage('Let’s learn about $suggestion in $_selectedLanguage!');
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add({
        'text': 'Chat cleared! How can I help you learn $_selectedLanguage today?',
        'isUser': false,
        'timestamp': DateTime.now(),
      });
    });
    _scrollToBottom();
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
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: theme.iconTheme.color,
                          size: size.width * 0.06,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          "Chat and Learn - $_selectedLanguage",
                          style: GoogleFonts.poppins(
                            fontSize: size.width * 0.045,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _clearChat,
                        child: Text(
                          "Clear Chat",
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF2196F3),
                            fontSize: size.width * 0.035,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(size.width * 0.04),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _buildMessageBubble(_messages[index], index, size),
                  ),
                ),
                _buildInputArea(size),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, int index, Size size) {
    final isUser = message['isUser'] as bool;
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    bool isLastBotMessage = false;
    if (!isUser) {
      int lastBotIndex = -1;
      for (int i = _messages.length - 1; i >= 0; i--) {
        if (!_messages[i]['isUser']) {
          lastBotIndex = i;
          break;
        }
      }
      isLastBotMessage = index == lastBotIndex;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: size.height * 0.01),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: EdgeInsets.only(left: size.width * 0.02, bottom: size.height * 0.005),
              child: CircleAvatar(
                radius: size.width * 0.04,
                backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
                child: Icon(
                  Icons.assistant,
                  size: size.width * 0.05,
                  color: const Color(0xFF2196F3),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (isUser) SizedBox(width: size.width * 0.12),
              Flexible(
                child: Container(
                  padding: EdgeInsets.all(size.width * 0.03),
                  constraints: BoxConstraints(maxWidth: size.width * 0.75),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF2196F3)
                        : isDarkMode
                        ? const Color(0xFF2A2A2A)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(size.width * 0.05),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: size.width * 0.02,
                        offset: Offset(0, size.height * 0.005),
                      ),
                    ],
                  ),
                  child: Text(
                    message['text'],
                    style: GoogleFonts.poppins(
                      color: isUser
                          ? Colors.white
                          : isDarkMode
                          ? Colors.white70
                          : Colors.black87,
                      fontSize: size.width * 0.035,
                    ),
                  ),
                ),
              ),
              if (!isUser) SizedBox(width: size.width * 0.12),
            ],
          ),
          if (!isUser && isLastBotMessage)
            Padding(
              padding: EdgeInsets.only(top: size.height * 0.01, left: size.width * 0.02),
              child: Wrap(
                spacing: size.width * 0.02,
                runSpacing: size.height * 0.01,
                children: _suggestions.map((suggestion) => ActionChip(
                  label: Text(
                    suggestion,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF2196F3),
                      fontSize: size.width * 0.03,
                    ),
                  ),
                  backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(size.width * 0.03),
                    side: const BorderSide(color: Color(0xFF2196F3)),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.03, vertical: size.height * 0.005),
                  onPressed: () => _addSuggestionMessage(suggestion),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputArea(Size size) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
                borderRadius: BorderRadius.circular(size.width * 0.05),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: size.width * 0.02,
                    offset: Offset(0, size.height * 0.005),
                  ),
                ],
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: "Type your message...",
                  hintStyle: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.white54 : Colors.grey[400],
                    fontSize: size.width * 0.035,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(size.width * 0.05),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.015),
                ),
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                  fontSize: size.width * 0.035,
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
              onPressed: () => _sendMessage(_messageController.text),
              padding: EdgeInsets.all(size.width * 0.03),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}