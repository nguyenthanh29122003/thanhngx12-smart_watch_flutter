// lib/screens/core/chatbot_screen.dart
import 'package:flutter/material.dart';
import '../../generated/app_localizations.dart';
import '../../services/open_router_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  void _sendMessage() async {
    final messageText = _messageController.text.trim(); // <<< Thêm trim()

    // Chỉ kiểm tra messageText
    if (messageText.isEmpty) {
      return;
    }

    final l10n = AppLocalizations.of(context)!; // Lấy l10n

    final userMessage = {
      'role': 'user',
      'content': messageText,
    };

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _messageController.clear();
    });

    try {
      final service = OpenRouterService();
      // <<< CHỈ CÒN GỌI getHealthAdvice >>>
      String response = await service.getHealthAdvice(messageText);

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': response,
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': l10n.errorSendingMessage, // Đã dùng l10n
        });
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatbotTitle)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final reversedIndex = _messages.length - 1 - index;
                final message = _messages[reversedIndex];
                final isUser = message['role'] == 'user';

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: isUser
                        ? Text(
                            message['content'].toString(),
                            style: TextStyle(color: Colors.blue[900]),
                          )
                        : MarkdownBody(
                            data: message['content'].toString(),
                            selectable: true,
                          ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: l10n.enterMessage, // Đã dịch
                          border: const OutlineInputBorder(),
                        ),
                        textCapitalization:
                            TextCapitalization.sentences, // Tự viết hoa đầu câu
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _isLoading ? null : _sendMessage,
                      tooltip: l10n.sendMessage, // Đã dịch
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Text(
                  AppLocalizations.of(context)!.healthDisclaimer,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                    fontSize: 12.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
