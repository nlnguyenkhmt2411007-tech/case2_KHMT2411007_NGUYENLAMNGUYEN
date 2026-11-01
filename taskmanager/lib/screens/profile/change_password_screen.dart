import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_loading) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
    });

    final result = await AuthService.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    if (result['success'] == true) {
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đổi mật khẩu thành công. Vui lòng đăng nhập lại.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ?? 'Không thể đổi mật khẩu',
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    required bool hidden,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: IconButton(
        tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
        onPressed: _loading ? null : onToggle,
        icon: Icon(
          hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Đổi mật khẩu'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Center(
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.lock_reset_rounded,
                        color: Color(0xFF2563EB),
                        size: 54,
                      ),

                      const SizedBox(height: 14),

                      const Text(
                        'Bảo mật tài khoản',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Nhập mật khẩu hiện tại và mật khẩu mới',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),

                      const SizedBox(height: 28),

                      TextFormField(
                        controller: _currentController,
                        enabled: !_loading,
                        obscureText: _hideCurrent,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.next,
                        decoration: _decoration(
                          label: 'Mật khẩu hiện tại',
                          icon: Icons.lock_outline,
                          hidden: _hideCurrent,
                          onToggle: () {
                            setState(() {
                              _hideCurrent = !_hideCurrent;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập mật khẩu hiện tại';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      TextFormField(
                        controller: _newController,
                        enabled: !_loading,
                        obscureText: _hideNew,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        decoration: _decoration(
                          label: 'Mật khẩu mới',
                          icon: Icons.key_outlined,
                          hidden: _hideNew,
                          onToggle: () {
                            setState(() {
                              _hideNew = !_hideNew;
                            });
                          },
                        ),
                        validator: (value) {
                          final password = value ?? '';

                          if (password.length < 8) {
                            return 'Mật khẩu mới phải có ít nhất 8 ký tự';
                          }

                          if (password == _currentController.text) {
                            return 'Mật khẩu mới phải khác mật khẩu cũ';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      TextFormField(
                        controller: _confirmController,
                        enabled: !_loading,
                        obscureText: _hideConfirm,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_loading) {
                            _changePassword();
                          }
                        },
                        decoration: _decoration(
                          label: 'Xác nhận mật khẩu mới',
                          icon: Icons.verified_user_outlined,
                          hidden: _hideConfirm,
                          onToggle: () {
                            setState(() {
                              _hideConfirm = !_hideConfirm;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value != _newController.text) {
                            return 'Mật khẩu xác nhận không khớp';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Sau khi đổi mật khẩu thành công, '
                        'bạn cần đăng nhập lại.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _changePassword,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _loading
                                ? 'Đang đổi mật khẩu...'
                                : 'Lưu mật khẩu mới',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
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
      ),
    );
  }
}
