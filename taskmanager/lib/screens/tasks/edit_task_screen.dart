import 'package:flutter/material.dart';

import '../../services/task_service.dart';

class EditTaskScreen extends StatefulWidget {
  final Map<String, dynamic> task;

  const EditTaskScreen({super.key, required this.task});

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  static const Color primaryColor = Color(0xFF2563EB);

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  String _status = 'chua_thuc_hien';
  String _priority = 'trung_binh';

  DateTime? _startDate;
  DateTime? _dueDate;

  bool _saving = false;

  String get _taskId => (widget.task['_id'] ?? '').toString();

  @override
  void initState() {
    super.initState();

    // Tự điền dữ liệu công việc hiện tại.
    _titleController = TextEditingController(
      text: (widget.task['title'] ?? '').toString(),
    );

    _descriptionController = TextEditingController(
      text: (widget.task['description'] ?? '').toString(),
    );

    final currentStatus = (widget.task['status'] ?? '').toString();

    if (const [
      'chua_thuc_hien',
      'dang_thuc_hien',
      'da_hoan_thanh',
    ].contains(currentStatus)) {
      _status = currentStatus;
    }

    final currentPriority = (widget.task['priority'] ?? '').toString();

    if (const ['thap', 'trung_binh', 'cao'].contains(currentPriority)) {
      _priority = currentPriority;
    }

    _startDate = _parseDate(widget.task['startDate']);
    _dueDate = _parseDate(widget.task['dueDate']);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // =====================================================
  // 1. ĐỌC NGÀY TỪ MONGODB
  // =====================================================

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    final raw = value.toString();

    if (raw.length < 10) return null;

    // Backend lưu ngày dạng YYYY-MM-DDT00:00:00.000Z.
    // Lấy phần YYYY-MM-DD để tránh lệch ngày do múi giờ.
    final datePart = raw.substring(0, 10);

    final parts = datePart.split('-');

    if (parts.length != 3) return null;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null || month == null || day == null) {
      return null;
    }

    if (year < 2020 || year > 2100) {
      return null;
    }

    final date = DateTime(year, month, day);

    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }

    return date;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa thiết lập';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // =====================================================
  // 2. CHỌN NGÀY
  // =====================================================

  Future<void> _pickDate({required bool isStartDate}) async {
    if (_saving) return;

    final currentDate = isStartDate ? _startDate : _dueDate;

    final now = DateTime.now();

    final initialDate =
        currentDate ??
        (now.year >= 2020 && now.year <= 2100 ? now : DateTime(2026, 11, 3));

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100, 12, 31),
      helpText: isStartDate ? 'Chọn ngày bắt đầu' : 'Chọn hạn hoàn thành',
    );

    if (!mounted || selected == null) return;

    setState(() {
      if (isStartDate) {
        _startDate = selected;
      } else {
        _dueDate = selected;
      }
    });
  }

  // =====================================================
  // 3. LƯU CHỈNH SỬA
  // =====================================================

  Future<void> _saveChanges() async {
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

    final result = await TaskService.updateTask(
      taskId: _taskId,
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
      // Trả kết quả thành công cho trang Chi tiết.
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ?? 'Không thể cập nhật công việc',
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =====================================================
  // 4. TRANG TRÍ Ô NHẬP
  // =====================================================

  InputDecoration _decoration({
    required String label,
    IconData? icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    );
  }

  // =====================================================
  // 5. GIAO DIỆN CHỌN NGÀY
  // =====================================================

  Widget _dateField({
    required String title,
    required DateTime? value,
    required VoidCallback onSelect,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
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
                  onTap: _saving ? null : onSelect,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          color: primaryColor,
                          size: 19,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _formatDate(value),
                            style: TextStyle(
                              fontSize: 14,
                              color: value == null
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
              if (value != null)
                IconButton(
                  onPressed: _saving ? null : onClear,
                  tooltip: 'Bỏ ngày',
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // =====================================================
  // 6. GIAO DIỆN CHỈNH SỬA
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Chỉnh sửa công việc',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Cập nhật thông tin',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Chỉnh sửa nội dung và lưu thay đổi.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),

                  const SizedBox(height: 24),

                  // Tên công việc
                  TextFormField(
                    controller: _titleController,
                    enabled: !_saving,
                    maxLength: 200,
                    decoration: _decoration(
                      label: 'Tên công việc *',
                      icon: Icons.task_alt_outlined,
                    ),
                    validator: (value) {
                      final name = value?.trim() ?? '';

                      if (name.length < 2) {
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

                  const SizedBox(height: 16),

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
                    title: 'Ngày bắt đầu',
                    value: _startDate,
                    onSelect: () {
                      _pickDate(isStartDate: true);
                    },
                    onClear: () {
                      setState(() {
                        _startDate = null;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // Hạn hoàn thành
                  _dateField(
                    title: 'Hạn hoàn thành',
                    value: _dueDate,
                    onSelect: () {
                      _pickDate(isStartDate: false);
                    },
                    onClear: () {
                      setState(() {
                        _dueDate = null;
                      });
                    },
                  ),

                  const SizedBox(height: 30),

                  // Lưu thay đổi
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _saveChanges,
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
                      label: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

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
