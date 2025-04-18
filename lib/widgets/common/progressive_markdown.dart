// lib/widgets/common/progressive_markdown.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // Cần thiết để render Markdown

class ProgressiveMarkdown extends StatefulWidget {
  /// Chuỗi văn bản Markdown đầy đủ cần hiển thị.
  final String fullText;

  /// Khoảng thời gian (tính bằng mili giây) giữa mỗi lần cập nhật hiển thị một phần text.
  /// Giá trị nhỏ hơn sẽ làm animation nhanh hơn.
  final Duration updateInterval;

  /// Số lượng ký tự được thêm vào hiển thị trong mỗi khoảng `updateInterval`.
  /// Giá trị lớn hơn sẽ làm animation "nhảy" nhiều hơn nhưng nhanh hơn tổng thể.
  final int charsPerInterval;

  /// Callback tùy chọn sẽ được gọi một lần khi animation hiển thị hoàn thành.
  final VoidCallback? onCompleted;

  /// Style sheet tùy chọn để định dạng văn bản Markdown.
  /// Nếu null, sẽ sử dụng theme mặc định.
  final MarkdownStyleSheet? styleSheet;

  /// Callback tùy chọn để xử lý khi người dùng nhấn vào một liên kết trong Markdown.
  final MarkdownTapLinkCallback? onTapLink;

  const ProgressiveMarkdown({
    super.key,
    required this.fullText,
    this.updateInterval =
        const Duration(milliseconds: 60), // Tốc độ mặc định: 40ms/lần
    this.charsPerInterval = 5, // Số ký tự mặc định: 3 ký tự/lần
    this.onCompleted,
    this.styleSheet,
    this.onTapLink,
  });

  @override
  State<ProgressiveMarkdown> createState() => _ProgressiveMarkdownState();
}

class _ProgressiveMarkdownState extends State<ProgressiveMarkdown> {
  // Sử dụng ValueNotifier để lưu trữ và thông báo sự thay đổi của đoạn text đang hiển thị.
  // Khởi tạo với chuỗi rỗng.
  late final ValueNotifier<String> _currentTextNotifier;
  Timer? _timer; // Timer để điều khiển việc cập nhật text theo định kỳ.
  int _currentCharIndex = 0; // Index của ký tự cuối cùng đã được hiển thị.

  @override
  void initState() {
    super.initState();
    _currentTextNotifier = ValueNotifier<String>(''); // Khởi tạo notifier
    _startStreamingText(); // Bắt đầu chạy hiệu ứng khi widget được tạo.
    print(
        "[ProgressiveMarkdown] initState for key: ${widget.key}"); // Debug log
  }

  @override
  void didUpdateWidget(covariant ProgressiveMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nếu nội dung `fullText` được truyền vào bị thay đổi (ví dụ: widget được tái sử dụng với text khác),
    // chúng ta cần khởi động lại animation.
    if (widget.fullText != oldWidget.fullText) {
      print(
          "[ProgressiveMarkdown] Text changed (key: ${widget.key}), restarting animation."); // Debug log
      _timer?.cancel(); // Hủy timer cũ.
      _currentCharIndex = 0; // Reset index về đầu.
      _currentTextNotifier.value = ''; // Reset nội dung hiển thị về rỗng.
      _startStreamingText(); // Bắt đầu lại animation với text mới.
    }
  }

  @override
  void dispose() {
    print("[ProgressiveMarkdown] dispose for key: ${widget.key}"); // Debug log
    _timer?.cancel(); // Luôn hủy timer khi widget bị hủy để tránh rò rỉ bộ nhớ.
    _currentTextNotifier.dispose(); // Hủy ValueNotifier.
    super.dispose();
  }

  /// Bắt đầu hoặc tiếp tục chạy hiệu ứng hiển thị text từ từ.
  void _startStreamingText() {
    _timer?.cancel(); // Đảm bảo timer cũ đã bị hủy trước khi tạo timer mới.

    // Tạo timer mới, lặp lại theo khoảng `widget.updateInterval`.
    _timer = Timer.periodic(widget.updateInterval, (timer) {
      // Kiểm tra xem đã hiển thị hết chuỗi `fullText` chưa.
      if (_currentCharIndex < widget.fullText.length) {
        // Nếu chưa, tăng index lên theo `charsPerInterval`.
        // `clamp` đảm bảo index không vượt quá độ dài chuỗi.
        _currentCharIndex = (_currentCharIndex + widget.charsPerInterval)
            .clamp(0, widget.fullText.length);

        // Cập nhật giá trị của ValueNotifier bằng chuỗi con từ đầu đến index hiện tại.
        // Việc gán `.value` sẽ tự động kích hoạt các listener (như ValueListenableBuilder).
        _currentTextNotifier.value =
            widget.fullText.substring(0, _currentCharIndex);
      } else {
        // Nếu đã hiển thị hết chuỗi (`_currentCharIndex` đã bằng hoặc lớn hơn độ dài).
        timer.cancel(); // Dừng timer lại.
        widget.onCompleted
            ?.call(); // Gọi callback `onCompleted` nếu được cung cấp.
        print(
            "[ProgressiveMarkdown] Animation completed for key: ${widget.key}"); // Debug log
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sử dụng ValueListenableBuilder để lắng nghe sự thay đổi của _currentTextNotifier.
    // Widget này sẽ tự động build lại mỗi khi notifier cập nhật giá trị.
    return ValueListenableBuilder<String>(
      valueListenable: _currentTextNotifier,
      builder: (context, currentText, child) {
        // Luôn hiển thị MarkdownBody.
        // `currentText` sẽ được cập nhật từ từ bởi ValueNotifier.
        return MarkdownBody(
          // Hiển thị "..." nếu chưa có ký tự nào và animation chưa xong,
          // ngược lại hiển thị `currentText`.
          data:
              currentText.isEmpty && _currentCharIndex < widget.fullText.length
                  ? "..." // Placeholder ban đầu
                  : currentText,
          selectable: true, // Cho phép người dùng chọn và sao chép text.
          // Sử dụng styleSheet được truyền vào hoặc tạo từ theme mặc định.
          styleSheet: widget.styleSheet ??
              MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                // Ví dụ: Tùy chỉnh style cho paragraph (văn bản thường)
                p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors
                          .black87, // Màu chữ mặc định cho nội dung markdown
                      height: 1.4, // Giãn dòng nếu muốn
                    ),
                // Thêm các tùy chỉnh khác nếu cần (ví dụ: bold, italic, list...)
                // strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              ),
          // Truyền callback xử lý link nếu có.
          onTapLink: widget.onTapLink,
        );
      },
    );
  }
}
