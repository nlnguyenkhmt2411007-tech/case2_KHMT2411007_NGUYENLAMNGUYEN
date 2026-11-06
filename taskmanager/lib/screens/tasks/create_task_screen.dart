import 'package:flutter/material.dart';

import '../../services/task_service.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  static const Color primaryColor = Color(0xFF2563EB);

  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _status = 'chua_thuc_hien';
  String _priority = 'trung_binh';

  DateTime? _startDate;
  DateTime? _dueDate;

  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // =====================================================
  // 1. ĐỊNH DẠNG NGÀY
  // =====================================================

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Chọn ngày';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // =====================================================
  // 2. CHỌN NGÀY BẮT ĐẦU
  // =====================================================

  Future<void> _pickStartDate() async {
    if (_saving) return;

    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Chọn ngày bắt đầu',
    );

    if (!mounted || selected == null) return;

    setState(() {
      _startDate = selected;
    });
  }

  // =====================================================
  // 3. CHỌN HẠN HOÀN THÀNH
  // =====================================================

  Future<void> _pickDueDate() async {
    if (_saving) return;

    final initial =
        _dueDate ??
        (_startDate != null && _startDate!.isAfter(DateTime.now())
            ? _startDate!
            : DateTime.now());

    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Chọn hạn hoàn thành',
    );

    if (!mounted || selected == null) return;

    setState(() {
      _dueDate = selected;
    });
  }

  // =====================================================
  // 4. LƯU CÔNG VIỆC
  // =====================================================

  Future<void> _saveTask() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate != null &&
        _dueDate != null &&
        _dueDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hạn hoàn thành không được trước ngày bắt đầu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final result = await TaskService.createTask(
      title: _titleController.text,
      description: _descriptionController.text,
      status: _status,
      priority: _priority,
      startDate: _startDate,
      dueDate: _dueDate,
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
    });

    if (result['success'] == true) {
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ?? 'Không thể tạo công việc',
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =====================================================
  // 5. TRANG TRÍ FORM
  // =====================================================

  InputDecoration _decoration({
    required String label,
    IconData? icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
    );
  }

  // =====================================================
  // 6. Ô CHỌN NGÀY
  // =====================================================

  Widget _dateField({
    required String label,
    required DateTime? date,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _saving ? null : onPick,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          color: primaryColor,
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _formatDate(date),
                            style: TextStyle(
                              fontSize: 13,
                              color: date == null
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (date != null)
                IconButton(
                  onPressed: _saving ? null : onClear,
                  tooltip: 'Bỏ ngày đã chọn',
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // =====================================================
  // 7. GIAO DIỆN TẠO CÔNG VIỆC
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text(
          'Thêm công việc',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Thông tin công việc',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Nhập thông tin để tạo công việc mới.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),

                  const SizedBox(height: 24),

                  // Tên công việc
                  TextFormField(
                    controller: _titleController,
                    enabled: !_saving,
                    maxLength: 200,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(
                      label: 'Tên công việc *',
                      icon: Icons.task_alt_outlined,
                      hint: 'Ví dụ: Hoàn thành bài tập Flutter',
                    ),
                    validator: (value) {
                      final title = value?.trim() ?? '';

                      if (title.length < 2) {
                        return 'Tên phải có ít nhất 2 ký tự';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  // Mô tả
                  TextFormField(
                    controller: _descriptionController,
                    enabled: !_saving,
                    maxLines: 4,
                    maxLength: 5000,
                    decoration: _decoration(
                      label: 'Mô tả công việc',
                      hint: 'Nhập mô tả chi tiết...',
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Trạng thái
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    isExpanded: true,
                    decoration: _decoration(
                      label: 'Trạng thái',
                      icon: Icons.pending_actions_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'chua_thuc_hien',
                        child: Text('Chưa thực hiện'),
                      ),
                      DropdownMenuItem(
                        value: 'dang_thuc_hien',
                        child: Text('Đang thực hiện'),
                      ),
                      DropdownMenuItem(
                        value: 'da_hoan_thanh',
                        child: Text('Đã hoàn thành'),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _status = value;
                              });
                            }
                          },
                  ),

                  const SizedBox(height: 20),

                  // Mức độ ưu tiên
                  DropdownButtonFormField<String>(
                    initialValue: _priority,
                    isExpanded: true,
                    decoration: _decoration(
                      label: 'Mức độ ưu tiên',
                      icon: Icons.flag_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'thap', child: Text('Thấp')),
                      DropdownMenuItem(
                        value: 'trung_binh',
                        child: Text('Trung bình'),
                      ),
                      DropdownMenuItem(value: 'cao', child: Text('Cao')),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _priority = value;
                              });
                            }
                          },
                  ),

                  const SizedBox(height: 24),

                  // Ngày bắt đầu
                  _dateField(
                    label: 'Ngày bắt đầu',
                    date: _startDate,
                    onPick: _pickStartDate,
                    onClear: () {
                      setState(() {
                        _startDate = null;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // Hạn hoàn thành
                  _dateField(
                    label: 'Hạn hoàn thành',
                    date: _dueDate,
                    onPick: _pickDueDate,
                    onClear: () {
                      setState(() {
                        _dueDate = null;
                      });
                    },
                  ),

                  const SizedBox(height: 30),

                  // Nút lưu công việc
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _saveTask,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Đang lưu...' : 'Lưu công việc'),
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Nút hủy
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () {
                            Navigator.of(context).pop(false);
                          },
                    child: const Text('Hủy'),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
