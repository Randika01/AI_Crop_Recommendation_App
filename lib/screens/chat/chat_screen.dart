import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();

  // Generate unique session ID for this chat
  final String _sessionId = const Uuid().v4();

  late List<ChatMessage> _messages;
  bool _isLoading = false;
  bool _apiConnected = false;

  @override
  void initState() {
    super.initState();
    _messages = [
      ChatMessage(
        text:
            'Hi! 👋 I\'m your Crop Disease Assistant. Tell me about any symptoms you\'re seeing on your plants, and I\'ll help diagnose the issue.',
        isBot: true,
        time: _getCurrentTime(),
      ),
    ];
    _checkApiConnection();
  }

  // Check if API is accessible
  Future<void> _checkApiConnection() async {
    final isHealthy = await _apiService.checkHealth();
    setState(() {
      _apiConnected = isHealthy;
    });

    if (!isHealthy) {
      _showSnackBar('⚠️ API Connection Failed - Check if Colab is running',
          Colors.orange);
    } else {
      _showSnackBar('✅ Connected to AI Assistant', Colors.green);
    }
  }

  // Get current time formatted
  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
  }

  // Send message to API and get response
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message to UI
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isBot: false,
        time: _getCurrentTime(),
      ));
      _isLoading = true;
      _messageController.clear();
    });

    // Auto scroll to bottom
    _scrollToBottom();

    try {
      // Send to API
      final response = await _apiService.getDiagnosis(
        query: text,
        sessionId: _sessionId,
      );

      // Add bot response
      setState(() {
        if (response.success) {
          _messages.add(ChatMessage(
            text: response.response ?? 'No response received',
            isBot: true,
            time: _getCurrentTime(),
          ));
        } else {
          _messages.add(ChatMessage(
            text: '❌ Error: ${response.error}',
            isBot: true,
            time: _getCurrentTime(),
          ));
        }
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: '❌ Error: ${e.toString()}',
          isBot: true,
          time: _getCurrentTime(),
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  // Scroll to bottom of chat
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // Show snackbar
  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Clear chat history
  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat?'),
        content:
            const Text('This will clear all messages in this conversation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _messages = [
                  ChatMessage(
                    text: 'Chat cleared! 🧹 How can I help you today?',
                    isBot: true,
                    time: _getCurrentTime(),
                  ),
                ];
              });
              Navigator.pop(context);
              _apiService.clearHistory(_sessionId);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _apiConnected ? Colors.green[300] : Colors.orange[300],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.agriculture,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Crop Disease Assistant',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _apiConnected ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: _apiConnected ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.textDark),
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Banner with greeting
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.primaryGreen,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tell me about your crop symptoms and I\'ll help diagnose the issue! 🌿',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline,
                      color: Colors.white, size: 20),
                  onPressed: () {
                    _showSnackBar(
                      'Describe symptoms like: color, texture, affected areas',
                      Colors.blue,
                    );
                  },
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            size: 60, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessage(_messages[index]);
                    },
                  ),
          ),

          // Loading indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(AppColors.primaryGreen),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AI is thinking...',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _messageController,
                        enabled: !_isLoading,
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: 'Describe symptoms...',
                          hintStyle: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: AppColors.textGrey,
                          ),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (text) => _sendMessage(text),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () => _sendMessage(_messageController.text),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _isLoading
                            ? Colors.grey[300]
                            : AppColors.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isBot) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.agriculture,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:
                    message.isBot ? AppColors.primaryGreen : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(message.isBot ? 4 : 18),
                  topRight: Radius.circular(message.isBot ? 18 : 4),
                  bottomLeft: const Radius.circular(18),
                  bottomRight: const Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: message.isBot ? Colors.white : AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.time,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: message.isBot ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
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

class ChatMessage {
  final String text;
  final bool isBot;
  final String time;

  ChatMessage({
    required this.text,
    required this.isBot,
    required this.time,
  });
}
