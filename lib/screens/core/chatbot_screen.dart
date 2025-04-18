// lib/screens/core/chatbot_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import nếu cần dùng provider khác
import '../../generated/app_localizations.dart'; // Import l10n
import '../../services/open_router_service.dart'; // Import service AI
import '../../widgets/common/progressive_markdown.dart'; // Import widget mới
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  // Cấu trúc message mới có 'isCompleted'
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoadingApi = false; // Trạng thái chờ API trả về
  bool _isAnimatingMessage = false; // Trạng thái có animation đang chạy không

  // ScrollController để tự cuộn xuống tin nhắn mới
  final ScrollController _scrollController = ScrollController();

  // Hàm setState an toàn
  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  // Hàm gửi tin nhắn
  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final userMessage = {'role': 'user', 'content': messageText};

    // Cập nhật UI ngay lập tức với tin nhắn người dùng và trạng thái loading/animating
    setStateIfMounted(() {
      _messages.add(userMessage);
      _isLoadingApi = true; // Bắt đầu chờ API
      _isAnimatingMessage = true; // Dự kiến tin nhắn AI tiếp theo sẽ animate
      _messageController.clear();
      _scrollToBottom(); // Cuộn xuống khi gửi
    });

    try {
      final service = OpenRouterService();
      // Giả lập độ trễ nhỏ của API (có thể bỏ nếu API nhanh)
      // await Future.delayed(const Duration(milliseconds: 500));
      String response = await service.getHealthAdvice(messageText);

      // Thêm tin nhắn AI với trạng thái chưa hoàn thành animation
      setStateIfMounted(() {
        _messages.add({
          'role': 'assistant',
          'content': response,
          'isCompleted': false, // Animation chưa chạy xong
        });
        _isLoadingApi = false; // Hết chờ API
        // _isAnimatingMessage vẫn là true cho đến khi animation của tin nhắn này xong
        _scrollToBottom(); // Cuộn xuống khi có tin nhắn mới
      });
    } catch (e) {
      print("!!! ChatbotScreen Error sending message: $e");
      // Thêm tin nhắn lỗi (coi như đã hoàn thành)
      setStateIfMounted(() {
        _messages.add({
          'role': 'assistant',
          'content': "${l10n.errorSendingMessage}.", // Hiển thị lỗi (đã dịch)
          'isCompleted': true, // Lỗi thì coi như xong
        });
        _isLoadingApi = false; // Hết chờ API
        _isAnimatingMessage = false; // Không có animation cho lỗi
        _scrollToBottom(); // Cuộn xuống
      });
    }
  }

  // Hàm đánh dấu animation của một tin nhắn đã hoàn thành
  void _markAnimationCompleted(int messageIndex) {
    if (mounted && messageIndex >= 0 && messageIndex < _messages.length) {
      // Chỉ cập nhật nếu tin nhắn đó chưa được đánh dấu hoàn thành
      if (_messages[messageIndex]['isCompleted'] == false) {
        // Kiểm tra xem đây có phải tin nhắn cuối cùng không
        bool wasLastMessage = (messageIndex == _messages.length - 1);
        setStateIfMounted(() {
          _messages[messageIndex]['isCompleted'] = true;
          // Nếu là tin nhắn cuối cùng thì tắt cờ animating chung
          if (wasLastMessage) {
            _isAnimatingMessage = false;
            print(
                "[ChatbotScreen] Last message animation completed. Send enabled.");
          }
        });
        print(
            "[ChatbotScreen] Animation completed for message index: $messageIndex");
      }
    }
  }

  // Hàm tự động cuộn xuống dưới cùng
  void _scrollToBottom() {
    // Delay một chút để ListView kịp cập nhật trước khi cuộn
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose(); // Dispose ScrollController
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Xác định nút gửi có bị vô hiệu hóa không
    final bool isSendDisabled = _isLoadingApi || _isAnimatingMessage;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatbotTitle), // Đã dịch
      ),
      body: Column(
        children: [
          // --- Danh sách tin nhắn ---
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // Gán ScrollController
              padding: const EdgeInsets.all(8.0),
              // <<< KHÔNG CẦN REVERSE nữa vì ProgressiveMarkdown xử lý thứ tự >>>
              // reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                // <<< KHÔNG CẦN ĐẢO NGƯỢC INDEX >>>
                // final reversedIndex = _messages.length - 1 - index;
                final message = _messages[index]; // Lấy index bình thường
                // ------------------------------------
                final isUser = message['role'] == 'user';
                final bool isCompleted =
                    message['isCompleted'] ?? true; // Trạng thái hoàn thành

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        vertical: 5.0,
                        horizontal: 8.0), // Thêm horizontal margin
                    padding: const EdgeInsets.symmetric(
                        vertical: 10.0, horizontal: 14.0), // Điều chỉnh padding
                    decoration: BoxDecoration(
                        color: isUser
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surfaceVariant, // Màu sắc theme
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16.0),
                          topRight: const Radius.circular(16.0),
                          bottomLeft: isUser
                              ? const Radius.circular(16.0)
                              : const Radius.circular(0), // Bo góc khác nhau
                          bottomRight: isUser
                              ? const Radius.circular(0)
                              : const Radius.circular(16.0),
                        ),
                        boxShadow: [
                          // Thêm đổ bóng nhẹ
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          )
                        ]),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width *
                            0.75), // Giới hạn chiều rộng tin nhắn
                    child: isUser
                        ? Text(
                            // Tin nhắn User
                            message['content'].toString(),
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer),
                          )
                        // Tin nhắn AI
                        : isCompleted
                            ? MarkdownBody(
                                // Hiển thị tĩnh khi đã xong
                                data: message['content'].toString(),
                                selectable: true,
                                styleSheet: MarkdownStyleSheet.fromTheme(
                                        Theme.of(context))
                                    .copyWith(
                                  p: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          height: 1.4),
                                ),
                                // onTapLink: ...,
                              )
                            : ProgressiveMarkdown(
                                // Hiển thị animation khi chưa xong
                                // Key nên duy nhất cho mỗi tin nhắn để đảm bảo reset đúng
                                key: ValueKey(message
                                    .hashCode), // Dùng hashCode của map làm key
                                fullText: message['content'].toString(),
                                onCompleted: () {
                                  // Cung cấp callback
                                  _markAnimationCompleted(
                                      index); // Gọi hàm đánh dấu với index đúng
                                },
                                styleSheet: MarkdownStyleSheet.fromTheme(
                                        Theme.of(context))
                                    .copyWith(
                                  p: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          height: 1.4),
                                ),
                                // onTapLink: ...,
                              ),
                  ),
                );
              },
            ),
          ),
          // --- Thanh trạng thái Loading API ---
          // Chỉ hiển thị khi _isLoadingApi là true (chờ API)
          if (_isLoadingApi)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text("AI is thinking...",
                      style:
                          Theme.of(context).textTheme.bodySmall), // TODO: Dịch
                ],
              ),
            ),
          // -----------------------------------
          // --- Phần nhập liệu ---
          Container(
            // Thêm viền và nền cho khu vực nhập liệu
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                    blurRadius: 5,
                    color: Colors.black.withOpacity(0.1),
                    offset: Offset(0, -2))
              ],
            ),
            padding: const EdgeInsets.only(
                left: 12.0,
                right: 8.0,
                top: 8.0,
                bottom: 8.0), // Điều chỉnh padding
            child: Column(
              // Giữ nguyên Column ở đây cho disclaimer
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: l10n.enterMessage, // Đã dịch
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none), // Bo tròn, bỏ viền
                          filled: true, // Thêm nền
                          fillColor: Colors.grey[100], // Màu nền
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10), // Padding bên trong
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted:
                            isSendDisabled ? null : (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(
                        width: 8), // Khoảng cách giữa TextField và nút
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: isSendDisabled
                          ? null
                          : _sendMessage, // Dùng biến isSendDisabled
                      tooltip: l10n.sendMessage, // Đã dịch
                      color: isSendDisabled
                          ? Colors.grey
                          : Theme.of(context).primaryColor, // Màu nút
                    ),
                  ],
                ),
                const SizedBox(height: 6.0), // Giảm khoảng cách chút
                Text(
                  // Disclaimer giữ nguyên
                  l10n.healthDisclaimer,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
