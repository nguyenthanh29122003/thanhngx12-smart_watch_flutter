// lib/screens/core/relatives_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/relatives_provider.dart'; // Import provider
import '../../models/relative.dart'; // Import model
import '../../generated/app_localizations.dart'; // <<< Đã import

// Chuyển thành StatefulWidget để quản lý TextEditingController và Dropdown state
class RelativesScreen extends StatefulWidget {
  const RelativesScreen({super.key});

  @override
  State<RelativesScreen> createState() => _RelativesScreenState();
}

class _RelativesScreenState extends State<RelativesScreen> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedRelationshipInDialog;

  // Danh sách các lựa chọn cho mối quan hệ
  // TODO: Cân nhắc dịch các giá trị này hoặc dùng key-value map
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
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // <<< THÊM HÀM HELPER ĐỂ DỊCH MỐI QUAN HỆ >>>
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
        return relationshipKey; // Trả về key gốc nếu không khớp
    }
  }

  // --- Hàm hiển thị dialog thêm người thân ---
  Future<void> _showAddRelativeDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final relativesProvider =
        Provider.of<RelativesProvider>(context, listen: false);
    _nameController.clear();
    _selectedRelationshipInDialog = null;
    final l10n = AppLocalizations.of(context)!; // Lấy l10n

    bool? success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.person_add_alt_1_outlined),
                  const SizedBox(width: 10),
                  Text(l10n.addRelativeDialogTitle), // Dùng key
                ],
              ),
              contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: l10n.relativeNameLabel, // Dùng key
                          hintText: l10n.relativeNameHint, // Dùng key
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.relativeNameValidation; // Dùng key
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedRelationshipInDialog,
                        hint: Text(l10n.relationshipHint), // Dùng key
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.relationshipLabel, // Dùng key
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.people_alt_outlined),
                        ),
                        items: _relationshipOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value, // Value vẫn là tiếng Anh ('Father')
                            child: Text(_getTranslatedRelationship(
                                value, l10n)), // Hiển thị text đã dịch
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          stfSetState(() {
                            _selectedRelationshipInDialog = newValue;
                          });
                        },
                        validator: (value) => (value == null)
                            ? l10n.relationshipValidation
                            : null, // Dùng key
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: Text(l10n.cancel), // Dùng key
                ),
                ElevatedButton(
                  onPressed: () async {
                    if ((formKey.currentState?.validate() ?? false) &&
                        _selectedRelationshipInDialog != null) {
                      final name = _nameController.text;
                      final relationship = _selectedRelationshipInDialog!;
                      final bool added = await relativesProvider.addRelative(
                          name, relationship);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(added);
                      }
                    }
                  },
                  child: Text(l10n.addRelativeButton), // Dùng key
                ),
              ],
            );
          },
        );
      },
    );

    // Hiển thị SnackBar kết quả
    if (mounted && success != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? l10n.relativeAddedSuccess
              : l10n.relativeAddedError), // Dùng key
          backgroundColor: success ? Colors.green : Colors.redAccent,
        ),
      );
    }
  }

  // --- Hàm hiển thị dialog xác nhận xóa ---
  Future<bool?> _showDeleteConfirmationDialog(
      BuildContext context, Relative relative) async {
    final l10n = AppLocalizations.of(context)!; // Lấy l10n
    return await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            Text(l10n.deleteRelativeConfirmationTitle), // Dùng key
          ],
        ),
        content: Text(l10n.confirmDeleteRelative(
            relative.name, relative.relationship)), // Dùng key với placeholder
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel), // Dùng key
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteButton), // Dùng key
          ),
        ],
      ),
    );
  }

  // --- Hàm hiển thị dialog sửa người thân ---
  Future<void> _showEditRelativeDialog(
      BuildContext context, Relative relativeToEdit) async {
    final formKey = GlobalKey<FormState>();
    final relativesProvider =
        Provider.of<RelativesProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!; // Lấy l10n

    _nameController.text = relativeToEdit.name;
    if (_relationshipOptions.contains(relativeToEdit.relationship)) {
      _selectedRelationshipInDialog = relativeToEdit.relationship;
    } else {
      _selectedRelationshipInDialog = 'Other';
      if (!_relationshipOptions.contains('Other')) {
        _relationshipOptions.add('Other');
      }
    }

    bool? success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.edit_note_outlined),
                  const SizedBox(width: 10),
                  Text(l10n.editRelativeDialogTitle), // <<< DÙNG KEY
                ],
              ),
              contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: l10n.relativeNameLabel, // Dùng key
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.relativeNameValidation; // Dùng key
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedRelationshipInDialog,
                        hint: Text(l10n.relationshipHint), // Dùng key
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.relationshipLabel, // Dùng key
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.people_alt_outlined),
                        ),
                        items: _relationshipOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value, // Value vẫn là tiếng Anh ('Father')
                            child: Text(_getTranslatedRelationship(
                                value, l10n)), // Hiển thị text đã dịch
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          stfSetState(() {
                            _selectedRelationshipInDialog = newValue;
                          });
                        },
                        validator: (value) => (value == null)
                            ? l10n.relationshipValidation
                            : null, // Dùng key
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: Text(l10n.cancel), // Dùng key
                ),
                ElevatedButton(
                  onPressed: () async {
                    if ((formKey.currentState?.validate() ?? false) &&
                        _selectedRelationshipInDialog != null) {
                      final newName = _nameController.text;
                      final newRelationship = _selectedRelationshipInDialog!;
                      if (newName == relativeToEdit.name &&
                          newRelationship == relativeToEdit.relationship) {
                        Navigator.of(dialogContext).pop(null);
                        return;
                      }
                      final bool updated =
                          await relativesProvider.updateRelative(
                              relativeToEdit.id, newName, newRelationship);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(updated);
                      }
                    }
                  },
                  child: Text(l10n.saveChangesButton), // <<< DÙNG KEY
                ),
              ],
            );
          },
        );
      },
    );

    // Hiển thị SnackBar kết quả cập nhật
    if (mounted && success != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? l10n.relativeUpdatedSuccess
              : l10n.relativeUpdatedError), // <<< DÙNG KEY
          backgroundColor: success ? Colors.green : Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final relativesProvider = context.watch<RelativesProvider>();
    final stream = relativesProvider.relativesStream;
    final l10n = AppLocalizations.of(context)!; // Lấy l10n ở đây

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.relativesScreenTitle), // Dùng key
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: l10n.addRelativeTooltip, // Dùng key
            onPressed: () => _showAddRelativeDialog(context),
          ),
        ],
      ),
      body: stream == null
          ? Center(child: Text(l10n.pleaseLoginRelatives)) // Dùng key
          : StreamBuilder<List<Relative>>(
              stream: stream,
              builder: (context, snapshot) {
                // ... (Xử lý waiting, error giữ nguyên, có thể thêm key dịch cho lỗi) ...
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print("Error in relatives stream builder: ${snapshot.error}");
                  // TODO: Thêm key dịch cho thông báo lỗi này
                  return Center(
                      child:
                          Text('Error loading relatives: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  // Hiển thị khi danh sách trống
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 70, color: Colors.grey.shade400),
                        const SizedBox(height: 20),
                        Text(l10n.noRelativesYet,
                            style: const TextStyle(fontSize: 18)), // Dùng key
                        const SizedBox(height: 5),
                        Text(l10n.addFirstRelativeHint,
                            style: TextStyle(color: Colors.grey.shade600),
                            textAlign: TextAlign.center), // Dùng key
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(/*...*/),
                          icon: const Icon(Icons.add),
                          label: Text(l10n.addRelativeEmptyButton), // Dùng key
                          onPressed: () => _showAddRelativeDialog(context),
                        ),
                      ],
                    ),
                  );
                }

                // Hiển thị danh sách người thân
                final relatives = snapshot.data!;
                return ListView.separated(
                  itemCount: relatives.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 0, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final relative = relatives[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 10.0),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          relative.name.isNotEmpty
                              ? relative.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontSize: 18),
                        ),
                      ),
                      title: Text(relative.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                      subtitle: Text(_getTranslatedRelationship(
                          relative.relationship,
                          l10n)), // TODO: Dịch relationship nếu cần
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // --- Nút Sửa ---
                          IconButton(
                            icon: Icon(Icons.edit_outlined,
                                color: Theme.of(context).colorScheme.secondary),
                            tooltip: l10n.editRelativeTooltip(
                                relative.name), // <<< DÙNG KEY
                            onPressed: () {
                              _showEditRelativeDialog(context, relative);
                            },
                          ),
                          // --- Nút Xóa ---
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: Colors.red.shade300),
                            tooltip: l10n.deleteRelativeTooltip(
                                relative.name), // Dùng key
                            onPressed: () async {
                              final confirm =
                                  await _showDeleteConfirmationDialog(
                                      context, relative);
                              if (confirm == true) {
                                final bool deleted = await context
                                    .read<RelativesProvider>()
                                    .deleteRelative(relative.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(deleted
                                          ? l10n.relativeDeletedSnackbar(
                                              relative.name)
                                          : l10n
                                              .relativeDeletedError), // Dùng key
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: deleted
                                          ? Colors.grey[700]
                                          : Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        _showEditRelativeDialog(context,
                            relative); // Gọi dialog sửa khi nhấn vào item
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
