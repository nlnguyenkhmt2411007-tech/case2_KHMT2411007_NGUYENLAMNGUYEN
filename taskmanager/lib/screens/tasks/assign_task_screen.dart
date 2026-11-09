import 'package:flutter/material.dart';

import '../../services/task_assignment_service.dart';

class AssignTaskScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;

  const AssignTaskScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
  });

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  static const Color primaryColor = Color(0xFF2563EB);
  static const Color dangerColor = Color(0xFFDC2626);

  final TextEditingController _emailsController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _submitting = false;

  @override
  void dispose() {
    _emailsController.dispose();
    super.dispose();
  }

  // =====================================================
  // C1. CHUYEN NOI DUNG THANH DANH SACH EMAIL
  // Moi dong mot email
  // =====================================================

  List<String> _parseEmails(String input) {
    return input
        .split(RegExp(r'[\r\n]+'))
        .map((email) => email.trim().toLowerCase())
        .where((email) => email.isNotEmpty)
        .toList();
  }

  // =====================================================
  // C1. KIEM TRA DU LIEU
  // =====================================================

  String? _validateEmails(String? value) {
    final emails = _parseEmails(value ?? '');

    if (emails.isEmpty) {
      return 'Vui lòng nhập ít nhất một email';
    }

    if (emails.length > 20) {
      return 'Chỉ được giao tối đa 20 người mỗi lần';
    }

    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    for (final email in emails) {
      if (email.length > 254 || !emailPattern.hasMatch(email)) {
        return 'Email không hợp lệ: $email';
      }
    }

    if (emails.toSet().length != emails.length) {
      return 'Danh sách có email bị trùng';
    }

    return null;
  }

  // =====================================================
  // C1. GOI API GIAO CONG VIEC
  // =====================================================

  Future<void> _assignTask() async {
    if (_submitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final emails = _parseEmails(_emailsController.text);

    setState(() {
      _submitting = true;
    });

    final result = await TaskAssignmentService.assignTask(
      taskId: widget.taskId,
      emails: emails,
    );

    if (!mounted) return;

    setState(() {
      _submitting = false;
    });

    if (result['success'] == true) {
      final total = result['totalAssignees'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            total is int
                ? 'Giao thành công. Tổng số người được giao: $total'
                : 'Giao công việc thành công',
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(true);
      return;
    }

    String message = (result['message'] ?? 'Không thể giao công việc')
        .toString();

    final missingEmails = result['missingEmails'];

    if (missingEmails is List && missingEmails.isNotEmpty) {
      message += '\nChưa đăng ký: ${missingEmails.join(', ')}';
    }

    final duplicateEmails = result['duplicateEmails'];

    if (duplicateEmails is List && duplicateEmails.isNotEmpty) {
      message += '\nĐã được giao: ${duplicateEmails.join(', ')}';
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: dangerColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // =====================================================
  // C1. GIAO DIEN
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text(
          'Giao công việc',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.group_add_outlined,
                              color: primaryColor,
                              size: 26,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'GIAO CHO NHIỀU THÀNH VIÊN',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Text(
                          widget.taskTitle,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          'Nhập email của những tài khoản đã đăng ký. '
                          'Mỗi dòng một email, tối đa 20 người mỗi lần.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _emailsController,
                          enabled: !_submitting,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          minLines: 4,
                          maxLines: 8,
                          autocorrect: false,
                          validator: _validateEmails,
                          decoration: InputDecoration(
                            labelText: 'Email người được giao',
                            hintText:
                                'member1@example.com\n'
                                'member2@example.com',
                            alignLabelWithHint: true,
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 70),
                              child: Icon(Icons.email_outlined),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF64748B),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Không nhập email của chính người tạo. '
                                'Không nhập lại người đã được giao.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _assignTask,
                      icon: _submitting
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.person_add_alt_1),
                      label: Text(
                        _submitting
                            ? 'Đang giao công việc...'
                            : 'Xác nhận giao công việc',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
