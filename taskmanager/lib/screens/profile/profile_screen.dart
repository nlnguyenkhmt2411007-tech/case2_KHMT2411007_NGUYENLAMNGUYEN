import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // =====================================================
  // 1. TẢI THÔNG TIN CÁ NHÂN
  // =====================================================

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AuthService.getMe();

    if (!mounted) return;

    setState(() {
      _loading = false;

      if (result['success'] == true && result['user'] is Map<String, dynamic>) {
        _user = result['user'] as Map<String, dynamic>;
      } else {
        _user = null;
        _error =
            result['message']?.toString() ?? 'Không thể tải thông tin cá nhân';
      }
    });
  }

  // =====================================================
  // 2. CHỈNH SỬA THÔNG TIN CÁ NHÂN
  // =====================================================

  Future<void> _editProfile() async {
    if (_saving || _user == null) return;

    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(
      text: _user?['fullName']?.toString() ?? '',
    );

    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> saveChanges() async {
                if (saving) return;

                if (!formKey.currentState!.validate()) {
                  return;
                }

                final newName = nameController.text.trim();

                setDialogState(() {
                  saving = true;
                });

                setState(() {
                  _saving = true;
                });

                final result = await AuthService.updateMe(fullName: newName);

                if (!mounted || !dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  saving = false;
                });

                setState(() {
                  _saving = false;
                });

                if (result['success'] == true) {
                  final updatedUser = result['user'];

                  if (updatedUser is Map<String, dynamic>) {
                    setState(() {
                      _user = updatedUser;
                    });
                  }

                  Navigator.of(dialogContext).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cập nhật thông tin cá nhân thành công'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );

                  await _loadProfile();
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result['message']?.toString() ??
                          'Không thể cập nhật thông tin',
                    ),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }

              return AlertDialog(
                title: const Text('Chỉnh sửa thông tin'),
                content: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cập nhật họ và tên của bạn.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: nameController,
                        enabled: !saving,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!saving) {
                            saveChanges();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Họ và tên',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          final name = value?.trim() ?? '';

                          if (name.length < 2 || name.length > 100) {
                            return 'Họ và tên phải có từ 2 đến 100 ký tự';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Email: ${_user?['email'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Hủy'),
                  ),
                  FilledButton.icon(
                    onPressed: saving ? null : saveChanges,
                    icon: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();

      if (mounted && _saving) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // =====================================================
  // 3. MỞ MÀN HÌNH ĐỔI MẬT KHẨU
  // =====================================================

  void _openChangePassword() {
    if (_loading || _saving) return;

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
  }

  // =====================================================
  // 4. ĐĂNG XUẤT
  // =====================================================

  void _logout() {
    AuthService.logout();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // =====================================================
  // 5. ĐỊNH DẠNG NGÀY
  // =====================================================

  String _formatDate(dynamic value) {
    if (value == null) return 'Chưa có thông tin';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return 'Chưa có thông tin';

    final local = date.toLocal();

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(local.day)}/'
        '${twoDigits(local.month)}/'
        '${local.year}';
  }

  // =====================================================
  // 6. HIỂN THỊ THÔNG TIN
  // =====================================================

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2563EB)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // 7. GIAO DIỆN TRANG THÔNG TIN CÁ NHÂN
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Thông tin cá nhân'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Tải lại thông tin',
            onPressed: (_loading || _saving) ? null : _loadProfile,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loadProfile,
                      child: const Text('Thử lại'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _logout,
                      child: const Text('Quay về đăng nhập'),
                    ),
                  ],
                ),
              ),
            )
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Color(0xFFE5E9F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const CircleAvatar(
                            radius: 38,
                            backgroundColor: Color(0xFFE8F0FF),
                            child: Icon(
                              Icons.person_outline,
                              color: Color(0xFF2563EB),
                              size: 42,
                            ),
                          ),

                          const SizedBox(height: 16),

                          Text(
                            _user?['fullName']?.toString() ?? 'Người dùng',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'Tài khoản Task Manager',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black54),
                          ),

                          const SizedBox(height: 24),

                          const Divider(),

                          _infoRow(
                            icon: Icons.badge_outlined,
                            label: 'Họ và tên',
                            value: _user?['fullName']?.toString() ?? '',
                          ),

                          _infoRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: _user?['email']?.toString() ?? '',
                          ),

                          _infoRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Ngày tạo tài khoản',
                            value: _formatDate(_user?['createdAt']),
                          ),

                          const SizedBox(height: 24),

                          // Chỉnh sửa thông tin cá nhân.
                          SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _editProfile,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Chỉnh sửa thông tin'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Đổi mật khẩu - chức năng riêng.
                          SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _openChangePassword,
                              icon: const Icon(Icons.lock_reset_outlined),
                              label: const Text('Đổi mật khẩu'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(
                                  color: Color(0xFF2563EB),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Đăng xuất.
                          SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _logout,
                              icon: const Icon(Icons.logout),
                              label: const Text('Đăng xuất'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
