// lib/screens/core/relatives_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/relatives_provider.dart'; // Import provider
import '../../models/relative.dart'; // Import model

// Chuyển thành StatefulWidget để quản lý TextEditingController và Dropdown state
class RelativesScreen extends StatefulWidget {
  const RelativesScreen({super.key});

  @override
  State<RelativesScreen> createState() => _RelativesScreenState();
}

class _RelativesScreenState extends State<RelativesScreen> {
  // Controller cho ô nhập tên
  final TextEditingController _nameController = TextEditingController();
  // Biến state để lưu giá trị được chọn trong Dropdown của Dialog
  String? _selectedRelationshipInDialog;

  // Danh sách các lựa chọn cho mối quan hệ
  final List<String> _relationshipOptions = [
    'Father', 'Mother', 'Son', 'Daughter', 'Brother', 'Sister',
    'Grandfather', 'Grandmother', 'Friend', 'Spouse', 'Partner', // Thêm Partner
    'Guardian', 'Doctor', 'Caregiver', 'Other', // Thêm các lựa chọn khác
  ];

  @override
  void dispose() {
    // Dispose controller khi State bị hủy
    _nameController.dispose();
    super.dispose();
  }

  // --- Hàm hiển thị dialog thêm người thân (với Dropdown) ---
  Future<void> _showAddRelativeDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    // Lấy provider (listen: false vì chỉ gọi hàm)
    final relativesProvider = Provider.of<RelativesProvider>(
      context,
      listen: false,
    );

    // Reset các trường nhập liệu trước khi mở dialog
    _nameController.clear();
    _selectedRelationshipInDialog =
        null; // Reset dropdown về trạng thái chưa chọn

    // Sử dụng showDialog và StatefulBuilder để quản lý state của Dropdown bên trong Dialog
    bool? success = await showDialog<bool>(
      context: context,
      barrierDismissible:
          false, // Ngăn đóng khi chạm ra ngoài để tránh mất dữ liệu đang nhập
      builder: (dialogContext) {
        // StatefulBuilder tạo ra một context và setState riêng cho nội dung Dialog
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return AlertDialog(
              title: const Row(
                // Thêm icon vào title
                children: [
                  Icon(Icons.person_add_alt_1_outlined),
                  SizedBox(width: 10),
                  Text("Add New Relative"),
                ],
              ),
              contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0),
              // Bọc Form trong SingleChildScrollView để tránh lỗi overflow
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: "Name",
                          hintText: "Enter relative's full name",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // --- DropdownButtonFormField cho Relationship ---
                      DropdownButtonFormField<String>(
                        value:
                            _selectedRelationshipInDialog, // Sử dụng biến state của dialog
                        hint: const Text('Select Relationship'),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Relationship", // Thêm label
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.people_alt_outlined),
                        ),
                        items:
                            _relationshipOptions.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          // Cập nhật state của StatefulBuilder (Dialog)
                          stfSetState(() {
                            // <<< Dùng stfSetState của StatefulBuilder
                            _selectedRelationshipInDialog = newValue;
                          });
                        },
                        validator:
                            (value) =>
                                (value == null)
                                    ? 'Please select a relationship'
                                    : null,
                      ),
                      // ------------------------------------
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                // Sửa kiểu dữ liệu cho rõ ràng
                TextButton(
                  onPressed:
                      () => Navigator.of(
                        dialogContext,
                      ).pop(null), // Trả về null khi Cancel
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Validate Form và kiểm tra Dropdown đã chọn chưa
                    if ((formKey.currentState?.validate() ?? false) &&
                        _selectedRelationshipInDialog != null) {
                      final name = _nameController.text;
                      final relationship = _selectedRelationshipInDialog!;

                      // Hiện loading (tùy chọn)
                      // ...

                      // Gọi hàm addRelative từ provider
                      final bool added = await relativesProvider.addRelative(
                        name,
                        relationship,
                      );

                      // Đóng dialog và trả về kết quả
                      if (dialogContext.mounted)
                        Navigator.of(dialogContext).pop(added);
                    }
                  },
                  child: const Text("Add Relative"),
                ),
              ],
            );
          },
        );
      },
    );

    // Hiển thị SnackBar kết quả sau khi dialog đóng (chỉ khi có kết quả trả về)
    if (mounted && success != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? "Relative added successfully!"
                : "Failed to add relative.",
          ),
          backgroundColor: success ? Colors.green : Colors.redAccent,
        ),
      );
    }
  } // Kết thúc _showAddRelativeDialog

  // --- Hàm hiển thị dialog xác nhận xóa ---
  Future<bool?> _showDeleteConfirmationDialog(
    BuildContext context,
    Relative relative,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Row(
              // Thêm icon
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 10),
                const Text("Confirm Deletion"),
              ],
            ),
            content: RichText(
              // Dùng RichText để định dạng
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium, // Style mặc định
                children: <TextSpan>[
                  const TextSpan(text: 'Are you sure you want to delete '),
                  TextSpan(
                    text: relative.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' (${relative.relationship})?'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text("Cancel"),
              ),
              // Nút xóa màu đỏ để nhấn mạnh hành động nguy hiểm
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text("Delete"),
              ),
            ],
          ),
    );
  } // Kết thúc _showDeleteConfirmationDialog

  @override
  Widget build(BuildContext context) {
    // Lấy provider (dùng watch để rebuild khi stream hoặc state provider thay đổi)
    final relativesProvider = context.watch<RelativesProvider>();
    final stream = relativesProvider.relativesStream; // Lấy stream từ provider

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatives'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined), // Icon thêm nhóm
            tooltip: 'Add Relative',
            onPressed: () => _showAddRelativeDialog(context), // Gọi hàm dialog
          ),
        ],
      ),
      body:
          stream ==
                  null // Kiểm tra stream có null không (khi chưa đăng nhập)
              ? const Center(child: Text('Please login to manage relatives.'))
              : StreamBuilder<List<Relative>>(
                stream: stream, // Sử dụng stream đã lấy
                builder: (context, snapshot) {
                  // --- Xử lý các trạng thái của Stream ---
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    ); // Đang tải dữ liệu
                  }
                  if (snapshot.hasError) {
                    print(
                      "Error in relatives stream builder: ${snapshot.error}",
                    );
                    return Center(
                      // Hiển thị lỗi thân thiện hơn
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          'Error loading relatives.\nPlease try again later.\n(${snapshot.error})',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    // Hiển thị thông báo và nút Add khi danh sách trống
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 70,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No relatives added yet.',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Tap the + button above to add your first relative.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Relative'),
                            onPressed:
                                () => _showAddRelativeDialog(
                                  context,
                                ), // Nút add ngay đây
                          ),
                        ],
                      ),
                    );
                  }

                  // --- Hiển thị danh sách khi có dữ liệu ---
                  final relatives = snapshot.data!;
                  return ListView.separated(
                    itemCount: relatives.length,
                    separatorBuilder:
                        (context, index) => const Divider(
                          height: 0,
                          indent: 16,
                          endIndent: 16,
                        ), // Kẻ ngang ngắn hơn
                    itemBuilder: (context, index) {
                      final relative = relatives[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 10.0,
                        ), // Tăng padding
                        leading: CircleAvatar(
                          radius: 24, // Avatar to hơn
                          backgroundColor:
                              Theme.of(
                                context,
                              ).colorScheme.primaryContainer, // Màu nền khác
                          child: Text(
                            relative.name.isNotEmpty
                                ? relative.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                              fontSize: 18,
                            ), // Màu chữ khác
                          ),
                        ),
                        title: Text(
                          relative.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(relative.relationship),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.red.shade300,
                          ),
                          tooltip: 'Delete ${relative.name}',
                          onPressed: () async {
                            // Gọi dialog xác nhận xóa
                            final confirm = await _showDeleteConfirmationDialog(
                              context,
                              relative,
                            );
                            if (confirm == true) {
                              // Gọi hàm xóa từ provider (dùng read vì chỉ gọi hàm)
                              final bool deleted = await context
                                  .read<RelativesProvider>()
                                  .deleteRelative(relative.id);
                              // Hiển thị SnackBar kết quả xóa
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      deleted
                                          ? "Relative '${relative.name}' deleted."
                                          : "Failed to delete relative.",
                                    ),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor:
                                        deleted
                                            ? Colors.grey[700]
                                            : Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        onTap: () {
                          // TODO: Mở màn hình chi tiết/chỉnh sửa (nếu cần)
                          print(
                            'Tapped on relative: ${relative.name} (ID: ${relative.id})',
                          );
                        },
                      );
                    },
                  );
                },
              ),
    );
  }
}
