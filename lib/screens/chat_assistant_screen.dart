import 'package:flutter/material.dart';
import '../services/groq_service.dart';

class ChatMessage {
  final String text;
  final bool isMe;

  ChatMessage({required this.text, required this.isMe});
}

class ChatAssistantScreen extends StatefulWidget {
  const ChatAssistantScreen({super.key});

  @override
  State<ChatAssistantScreen> createState() => _ChatAssistantScreenState();
}

class _ChatAssistantScreenState extends State<ChatAssistantScreen> {
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Hello! I am your BabyShopHub assistant. How can I help you care for your little one today?',
      isMe: false,
    ),
  ];
  
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GroqService _groqService = GroqService();
  bool _isTyping = false;

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

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(text: text, isMe: true));
      _isTyping = true;
    });
    _scrollToBottom();

    // Map conversation history to structure required by Groq API
    final history = _messages.map((m) => {
      'role': m.isMe ? 'user' : 'assistant',
      'content': m.text,
    }).toList();

    final response = await _groqService.getChatResponse(history);

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(text: response, isMe: false));
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'AI Assistant',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            fontFamily: 'Outfit',
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Message list area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: msg.isMe ? Colors.black87 : const Color(0xFFF9F9FB),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(msg.isMe ? 20 : 0),
                        bottomRight: Radius.circular(msg.isMe ? 0 : 20),
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.isMe ? Colors.white : Colors.black87,
                        fontSize: 14,
                        height: 1.4,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Typing indicators
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text('AI is thinking...', style: TextStyle(fontSize: 11, color: Colors.black38)),
                ],
              ),
            ),

          // Quick prompt suggestions
          if (_messages.length == 1)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: [
                  _buildQuickPrompt('Recommend diapers'),
                  _buildQuickPrompt('Is baby food organic?'),
                  _buildQuickPrompt('What is the return policy?'),
                ],
              ),
            ),

          // Text entry block
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 110, top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9FB),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextFormField(
                      controller: _controller,
                      onFieldSubmitted: _sendMessage,
                      decoration: const InputDecoration(
                        hintText: 'Type message...',
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _sendMessage(_controller.text),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompt(String prompt) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(prompt),
        onPressed: () => _sendMessage(prompt),
        backgroundColor: const Color(0xFFF9F9FB),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}
