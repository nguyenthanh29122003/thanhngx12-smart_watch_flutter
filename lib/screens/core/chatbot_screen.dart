import 'package:flutter/material.dart';
import '../../generated/app_localizations.dart';
import '../../services/open_router_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  void _sendMessage() async {
    final messageText = _messageController.text;
    final imageUrl = _imageUrlController.text;

    if (messageText.isEmpty && imageUrl.isEmpty) {
      return;
    }

    final userMessage = {
      'role': 'user',
      'content': messageText,
      'imageUrl': imageUrl,
    };

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _messageController.clear();
      _imageUrlController.clear();
    });

    try {
      final service = OpenRouterService();
      String response;
      if (imageUrl.isNotEmpty) {
        response = await service.analyzeImage(
          imageUrl,
          messageText.isEmpty ? 'Describe this image.' : messageText,
        );
      } else {
        response = await service.getHealthAdvice(messageText);
      }

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': response,
          'imageUrl': '',
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': '${AppLocalizations.of(context)!.errorSendingMessage}: $e',
          'imageUrl': '',
        });
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.chatbotTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message['imageUrl'].toString().isNotEmpty)
                          Image.network(
                            message['imageUrl'].toString(),
                            height: 100,
                            width: 100,
                            errorBuilder: (context, error, stackTrace) =>
                                const Text('Invalid image URL'),
                          ),
                        Text(
                          message['content'].toString(),
                          style: TextStyle(
                            color: isUser ? Colors.blue[900] : Colors.black,
                          ),
                        ),
                      ],
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
                TextField(
                  controller: _imageUrlController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.imageUrlLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.enterMessage,
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _isLoading ? null : _sendMessage,
                      tooltip: AppLocalizations.of(context)!.sendMessage,
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

  @override
  void dispose() {
    _messageController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }
}
