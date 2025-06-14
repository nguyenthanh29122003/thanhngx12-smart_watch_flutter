// lib/screens/core/relatives_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/relatives_provider.dart';
import '../../models/relative.dart';
import '../../generated/app_localizations.dart';

// <<<<<<<<<<<<<<<< BẮT ĐẦU CODE HOÀN CHỈNH >>>>>>>>>>>>>>>>

class RelativesScreen extends StatefulWidget {
  const RelativesScreen({super.key});

  @override
  State<RelativesScreen> createState() => _RelativesScreenState();
}

class _RelativesScreenState extends State<RelativesScreen> {
  // State controllers và các hàm logic được giữ lại hoàn toàn
  final TextEditingController _nameController = TextEditingController();
  String? _selectedRelationshipInDialog;
  final List<String> _relationshipOptions = [
    'Father',
    'Mother',
    'Son',
    'Daughter',
    'Brother',
    'Sister',
    'Grandfather',
    'Grandmother',
    'Friend',
    'Spouse',
    'Partner',
    'Guardian',
    'Doctor',
    'Caregiver',
    'Other'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // --- LOGIC HELPER & DIALOGS (sẽ được định nghĩa ở đây) ---
  // (Các hàm _show...Dialog và _getTranslatedRelationship sẽ ở đây)

  // <<< Dán code từ Phần 2 và 3 vào ĐÂY >>>

  // --- HÀM BUILD CHÍNH ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    // Lắng nghe stream từ provider
    final stream = context.watch<RelativesProvider>().relativesStream;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.relativesScreenTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            // Nút "Thêm" được thiết kế lại
            child: IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 28),
              tooltip: l10n.addRelativeTooltip,
              onPressed: () => _showAddOrEditRelativeDialog(), // Gọi hàm chung
              // Style nút cho nổi bật và hợp theme
              style: IconButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          )
        ],
      ),
      body: stream == null
          // Trường hợp người dùng chưa đăng nhập
          ? _MessageState(
              icon: Icons.login,
              message: l10n.pleaseLoginRelatives,
              color: theme.colorScheme.primary)
          : StreamBuilder<List<Relative>>(
              stream: stream,
              builder: (context, snapshot) {
                // Xử lý các trạng thái của Stream
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _MessageState(
                      icon: Icons.error_outline_rounded,
                      color: theme.colorScheme.error,
                      message: l10n.errorLoadingRelatives); // Key mới
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  // Hiển thị trạng thái rỗng nếu không có dữ liệu
                  return _EmptyState(
                      onAdd: () => _showAddOrEditRelativeDialog());
                }

                // Hiển thị danh sách người thân nếu có dữ liệu
                final relatives = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      16, 16, 16, 80), // Padding cho FAB
                  itemCount: relatives.length,
                  itemBuilder: (context, index) {
                    final relative = relatives[index];
                    return _RelativeListItemCard(
                      relative: relative,
                      onEdit: () => _showAddOrEditRelativeDialog(
                          relativeToEdit: relative),
                      onDelete: () => _showDeleteConfirmationDialog(relative),
                      // Truyền hàm dịch vào widget con
                      getTranslatedRelationship: (key) =>
                          _getTranslatedRelationship(key, l10n),
                    );
                  },
                );
              },
            ),
    );
  }

  // --- LOGIC HELPER & DIALOGS ---

  String _getTranslatedRelationship(
      String relationshipKey, AppLocalizations l10n) {
    switch (relationshipKey) {
      case 'Father':
        return l10n.relationFather;
      case 'Mother':
        return l10n.relationMother;
      case 'Son':
        return l10n.relationSon;
      case 'Daughter':
        return l10n.relationDaughter;
      case 'Brother':
        return l10n.relationBrother;
      case 'Sister':
        return l10n.relationSister;
      case 'Grandfather':
        return l10n.relationGrandfather;
      case 'Grandmother':
        return l10n.relationGrandmother;
      case 'Friend':
        return l10n.relationFriend;
      case 'Spouse':
        return l10n.relationSpouse;
      case 'Partner':
        return l10n.relationPartner;
      case 'Guardian':
        return l10n.relationGuardian;
      case 'Doctor':
        return l10n.relationDoctor;
      case 'Caregiver':
        return l10n.relationCaregiver;
      case 'Other':
        return l10n.relationOther;
      default:
        return relationshipKey;
    }
  }

  // --- HÀM DIALOG CHUNG CHO CẢ THÊM VÀ SỬA ---
  Future<void> _showAddOrEditRelativeDialog({Relative? relativeToEdit}) async {
    final bool isEditing = relativeToEdit != null;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Chuẩn bị form
    final formKey = GlobalKey<FormState>();
    _nameController.text = isEditing ? relativeToEdit.name : '';
    _selectedRelationshipInDialog =
        isEditing ? relativeToEdit.relationship : null;

    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // StatefulBuilder để dropdown có thể cập nhật state riêng trong dialog
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return AlertDialog(
              // Style dialog cho nhất quán với AppTheme
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              backgroundColor: theme.colorScheme.surface,
              title: Text(isEditing
                  ? l10n.editRelativeDialogTitle
                  : l10n.addRelativeDialogTitle),

              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // TextFormField với style từ AppTheme
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: l10n.relativeNameLabel,
                          hintText: l10n.relativeNameHint,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? l10n.relativeNameValidation
                            : null,
                      ),
                      const SizedBox(height: 16),
                      // DropdownButtonFormField
                      DropdownButtonFormField<String>(
                        value: _selectedRelationshipInDialog,
                        hint: Text(l10n.relationshipHint),
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.relationshipLabel,
                          border: const OutlineInputBorder(),
                        ),
                        // Tạo các item dropdown với text đã được dịch
                        items: _relationshipOptions
                            .map((value) => DropdownMenuItem<String>(
                                  value: value, // value vẫn là key tiếng Anh
                                  child: Text(
                                      _getTranslatedRelationship(value, l10n)),
                                ))
                            .toList(),
                        onChanged: (v) => stfSetState(
                            () => _selectedRelationshipInDialog = v),
                        validator: (v) =>
                            (v == null) ? l10n.relationshipValidation : null,
                      ),
                    ],
                  ),
                ),
              ),

              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: Text(l10n.cancel,
                      style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7))),
                ),
                // Nút ElevatedButton sẽ tự lấy style từ AppTheme
                ElevatedButton(
                  onPressed: () async {
                    if ((formKey.currentState?.validate() ?? false) &&
                        _selectedRelationshipInDialog != null) {
                      // Logic xử lý khi nhấn nút Lưu/Thêm
                      final name = _nameController.text.trim();
                      final relationship = _selectedRelationshipInDialog!;

                      // Lấy provider mà không lắng nghe thay đổi
                      final relativesProvider =
                          context.read<RelativesProvider>();

                      bool result = false;
                      if (isEditing) {
                        result = await relativesProvider.updateRelative(
                            relativeToEdit.id, name, relationship);
                      } else {
                        result = await relativesProvider.addRelative(
                            name, relationship);
                      }

                      // Đóng dialog và trả về kết quả thành công/thất bại
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(result);
                      }
                    }
                  },
                  child: Text(isEditing
                      ? l10n.saveChangesButton
                      : l10n.addRelativeButton),
                ),
              ],
            );
          },
        );
      },
    );

    // Hiển thị SnackBar thông báo kết quả sau khi dialog đóng
    if (mounted && success != null) {
      final successMessage =
          isEditing ? l10n.relativeUpdatedSuccess : l10n.relativeAddedSuccess;
      final errorMessage =
          isEditing ? l10n.relativeUpdatedError : l10n.relativeAddedError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? successMessage : errorMessage),
        backgroundColor:
            success ? Colors.green.shade600 : theme.colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // --- HÀM DIALOG XÁC NHẬN XÓA ---
  Future<void> _showDeleteConfirmationDialog(Relative relative) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // `showDialog` sẽ trả về true nếu người dùng nhấn "Xóa", ngược lại là false
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: theme.colorScheme.surface,
        title: Text(l10n.deleteRelativeConfirmationTitle),
        content: Text(l10n.confirmDeleteRelative(
          relative.name,
          _getTranslatedRelationship(relative.relationship, l10n),
        )),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel)),
          // Nút xóa được thiết kế lại để nguy hiểm hơn
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteButton),
          ),
        ],
      ),
    );

    // Chỉ thực hiện xóa nếu người dùng đã xác nhận
    if (confirm == true) {
      final bool deleted =
          await context.read<RelativesProvider>().deleteRelative(relative.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(deleted
              ? l10n.relativeDeletedSnackbar(relative.name)
              : l10n.relativeDeletedError),
          backgroundColor: deleted ? Colors.grey[700] : theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

// lib/screens/core/relatives_screen.dart

// ... code của _RelativesScreenState và các hàm dialog ở trên ...

// <<<<<<<<<<<<<<<< BẮT ĐẦU PHẦN 3 >>>>>>>>>>>>>>>>

// ================================================================
// CÁC WIDGET CON ĐỂ HIỂN THỊ TRẠNG THÁI VÀ DANH SÁCH
// ================================================================

// --- Widget hiển thị khi danh sách người thân trống ---
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Giao diện được thiết kế lại để thân thiện và khuyến khích hơn
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon lớn với màu nhẹ
            Icon(Icons.people_outline_rounded,
                size: 80, color: theme.colorScheme.primary.withOpacity(0.4)),
            const SizedBox(height: 24),
            // Tiêu đề sử dụng font Poppins
            Text(l10n.noRelativesYet, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            // Phụ đề
            Text(l10n.addFirstRelativeHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            // Nút kêu gọi hành động
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.addRelativeEmptyButton),
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Widget hiển thị thông báo lỗi hoặc thông tin chung ---
class _MessageState extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _MessageState(
      {required this.icon, required this.color, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: color, size: 64),
      const SizedBox(height: 16),
      Text(
        message,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
        textAlign: TextAlign.center,
      ),
    ]));
  }
}

// --- Widget Card hiển thị thông tin một người thân ---
class _RelativeListItemCard extends StatelessWidget {
  final Relative relative;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(String) getTranslatedRelationship;

  const _RelativeListItemCard(
      {required this.relative,
      required this.onEdit,
      required this.onDelete,
      required this.getTranslatedRelationship});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      // margin để tạo khoảng cách giữa các card
      margin: const EdgeInsets.only(bottom: 12.0),
      // InkWell để có hiệu ứng gợn sóng khi nhấn
      child: InkWell(
        onTap: () =>
            _showOptionsBottomSheet(context), // Mở bottom sheet khi nhấn
        borderRadius: BorderRadius.circular(16.0), // Bo góc cho hiệu ứng
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: Text(
                  relative.name.isNotEmpty
                      ? relative.name[0].toUpperCase()
                      : "?",
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 16),
              // Cột chứa tên và mối quan hệ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(relative.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      getTranslatedRelationship(relative.relationship),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // Chấm tròn chỉ báo trạng thái (placeholder)
              // Bạn sẽ cần thêm logic để cập nhật màu cho chấm này
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: Colors.green, // Ví dụ: Màu xanh lá cây là online
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              // Icon "Thêm" để gợi ý có thể nhấn vào
              Icon(Icons.more_vert_rounded, color: Colors.grey.shade400)
            ],
          ),
        ),
      ),
    );
  }

  // Hiển thị một BottomSheet với các tùy chọn Sửa/Xóa
  void _showOptionsBottomSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      // Nền trong suốt để thấy được bo tròn
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          // Bọc trong Container để có thể bo góc và thêm padding
          margin: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Có thể thêm một "handle" nhỏ ở trên
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              // Tùy chọn Sửa
              ListTile(
                leading:
                    Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                title: Text(l10n.editRelativeDialogTitle),
                onTap: () {
                  Navigator.pop(context); // Đóng bottom sheet trước
                  onEdit(); // Sau đó gọi hàm sửa
                },
              ),
              // Tùy chọn Xóa
              ListTile(
                leading:
                    Icon(Icons.delete_outline, color: theme.colorScheme.error),
                title: Text(l10n.delete),
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
              const SizedBox(height: 8), // Padding dưới cùng
            ],
          ),
        );
      },
    );
  }
}
