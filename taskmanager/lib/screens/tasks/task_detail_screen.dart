import 'package:flutter/material.dart';

import '../../services/task_service.dart';
import 'edit_task_screen.dart';
import 'assign_task_screen.dart';
import 'task_team_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  static const Color primaryColor = Color(0xFF2563EB);
  static const Color dangerColor = Color(0xFFDC2626);

  bool _loading = true;
  bool _deleting = false;
  String? _error;
  Map<String, dynamic>? _task;
  String _role = ''; // Mặc định không cấp quyền khi chưa xác nhận vai trò.

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  // =====================================================
  // B3. TẢI CHI TIẾT CÔNG VIỆC
  // =====================================================

  Future<void> _loadTask() async {
    if (!mounted || _deleting) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await TaskService.getTaskById(widget.taskId);

    if (!mounted) return;

    if (result['success'] == true && result['task'] is Map) {
      setState(() {
        _task = Map<String, dynamic>.from(result['task'] as Map);
        _role = (result['role'] ?? '').toString().toLowerCase();
        _loading = false;
      });
    } else {
      setState(() {
        _task = null;
        _role = '';
        _loading = false;
        _error = (result['message'] ?? 'Không thể tải chi tiết công việc')
            .toString();
      });
    }
  }

  // =====================================================
  // B4. MỞ MÀN HÌNH CHỈNH SỬA
  // =====================================================

  Future<void> _openEditTask() async {
    if (_loading ||
        _deleting ||
        _task == null ||
        !(_role == 'owner' || _role == 'editor')) {
      return;
    }

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditTaskScreen(task: Map<String, dynamic>.from(_task!)),
      ),
    );

    if (!mounted) return;

    if (updated == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật công việc thành công'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadTask();
    }
  }

  // =====================================================
  // B5. HỘP THOẠI XÁC NHẬN XÓA
  // =====================================================

  // =====================================================
  // C1. MO MAN HINH GIAO CONG VIEC
  // =====================================================

  Future<void> _openAssignTask() async {
    if (_loading || _deleting || _task == null || _role != 'owner') {
      return;
    }

    final assigned = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AssignTaskScreen(
          taskId: widget.taskId,
          taskTitle: (_task!['title'] ?? '').toString(),
        ),
      ),
    );

    if (!mounted) return;

    if (assigned == true) {
      await _loadTask();
    }
  }

  Future<void> _confirmDeleteTask() async {
    if (_loading || _deleting || _task == null || _role != 'owner') {
      return;
    }

    final title = (_task!['title'] ?? 'Công việc này').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: dangerColor,
            size: 42,
          ),
          title: const Text(
            'Xác nhận xóa công việc',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bạn có chắc muốn xóa công việc sau?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Hành động này không thể hoàn tác.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: dangerColor),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.end,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Xác nhận xóa'),
              style: FilledButton.styleFrom(
                backgroundColor: dangerColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    await _deleteTask();
  }

  // =====================================================
  // B5. GỌI API XÓA CÔNG VIỆC
  // =====================================================

  Future<void> _deleteTask() async {
    if (_deleting || _task == null || _role != 'owner') return;

    setState(() {
      _deleting = true;
    });

    final result = await TaskService.deleteTask(widget.taskId);

    if (!mounted) return;

    if (result['success'] == true) {
      // Trả true để màn hình Danh sách biết cần tải lại.
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _deleting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (result['message'] ?? 'Không thể xóa công việc').toString(),
        ),
        backgroundColor: dangerColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =====================================================
  // ĐỊNH DẠNG NGÀY
  // =====================================================

  String _formatDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'Chưa thiết lập';
    }

    final raw = value.toString();

    if (raw.length < 10) {
      return 'Ngày không hợp lệ';
    }

    final date = DateTime.tryParse(raw.substring(0, 10));

    if (date == null) {
      return 'Ngày không hợp lệ';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _formatDateTime(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'Chưa có thông tin';
    }

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) {
      return 'Không hợp lệ';
    }

    final local = parsed.toLocal();

    String two(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${two(local.day)}/${two(local.month)}/${local.year}'
        ' - ${two(local.hour)}:${two(local.minute)}';
  }

  // =====================================================
  // NHÃN TRẠNG THÁI
  // =====================================================

  String _statusLabel(String status) {
    switch (status) {
      case 'chua_thuc_hien':
        return 'Chưa thực hiện';
      case 'dang_thuc_hien':
        return 'Đang thực hiện';
      case 'da_hoan_thanh':
        return 'Đã hoàn thành';
      default:
        return 'Không xác định';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'chua_thuc_hien':
        return const Color(0xFF64748B);
      case 'dang_thuc_hien':
        return primaryColor;
      case 'da_hoan_thanh':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF64748B);
    }
  }

  // =====================================================
  // NHÃN ƯU TIÊN
  // =====================================================

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'thap':
        return 'Thấp';
      case 'trung_binh':
        return 'Trung bình';
      case 'cao':
        return 'Cao';
      default:
        return 'Không xác định';
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'thap':
        return const Color(0xFF059669);
      case 'trung_binh':
        return const Color(0xFFD97706);
      case 'cao':
        return dangerColor;
      default:
        return const Color(0xFF64748B);
    }
  }

  // =====================================================
  // GIAO DIỆN NHÃN
  // =====================================================

  Widget _tag({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // =====================================================
  // GIAO DIỆN MỘT DÒNG THÔNG TIN
  // =====================================================

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
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
  // NỘI DUNG CHI TIẾT CÔNG VIỆC
  // =====================================================

  Widget _buildTaskDetail() {
    final task = _task!;

    final title = (task['title'] ?? 'Không có tiêu đề').toString();

    final description = (task['description'] ?? '').toString();

    final status = (task['status'] ?? '').toString();

    final priority = (task['priority'] ?? '').toString();

    return RefreshIndicator(
      onRefresh: _loadTask,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
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
                const Text(
                  'THÔNG TIN CÔNG VIỆC',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),

                const SizedBox(height: 14),

                SelectableText(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),

                const SizedBox(height: 16),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _tag(
                      label: _statusLabel(status),
                      color: _statusColor(status),
                    ),
                    _tag(
                      label: 'Ưu tiên: ${_priorityLabel(priority)}',
                      color: _priorityColor(priority),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(),

                _infoRow(
                  icon: Icons.description_outlined,
                  title: 'Mô tả công việc',
                  value: description.isEmpty ? 'Chưa có mô tả' : description,
                ),

                _infoRow(
                  icon: Icons.event_available_outlined,
                  title: 'Ngày bắt đầu',
                  value: _formatDate(task['startDate']),
                ),

                _infoRow(
                  icon: Icons.event_outlined,
                  title: 'Hạn hoàn thành',
                  value: _formatDate(task['dueDate']),
                ),

                const Divider(),

                _infoRow(
                  icon: Icons.access_time_outlined,
                  title: 'Ngày tạo',
                  value: _formatDateTime(task['createdAt']),
                ),

                _infoRow(
                  icon: Icons.update_outlined,
                  title: 'Cập nhật lần cuối',
                  value: _formatDateTime(task['updatedAt']),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => TaskTeamScreen(
                        taskId: widget.taskId,
                        title: (_task?['title'] ?? '').toString(),
                      ),
                    ),
                  )
                  .then((_) {
                    if (mounted) _loadTask();
                  }),
              icon: const Icon(Icons.groups_outlined),
              label: const Text('Thành viên và chia sẻ'),
            ),
          ),
          const SizedBox(height: 12),

          if (_role == 'owner') ...[
            // C1: GIAO CONG VIEC CHO NHIEU NGUOI
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _deleting ? null : _openAssignTask,
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Giao công việc'),
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
          ],
          if (_role == 'owner' || _role == 'editor') ...[
            // B4: CHỈNH SỬA CÔNG VIỆC
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _deleting ? null : _openEditTask,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Chỉnh sửa công việc'),
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
          ],
          if (_role == 'owner') ...[
            // B5: XÓA CÔNG VIỆC
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _deleting ? null : _confirmDeleteTask,
                icon: _deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: dangerColor,
                        ),
                      )
                    : const Icon(Icons.delete_outline),
                label: Text(_deleting ? 'Đang xóa...' : 'Xóa công việc'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: dangerColor,
                  side: const BorderSide(color: dangerColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
          // LÀM MỚI
          OutlinedButton.icon(
            onPressed: _deleting ? null : _loadTask,
            icon: const Icon(Icons.refresh),
            label: const Text('Làm mới thông tin'),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // =====================================================
  // GIAO DIỆN CHÍNH
  // =====================================================

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadTask,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    } else {
      content = _buildTaskDetail();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text(
          'Chi tiết công việc',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            onPressed: (_loading || _deleting) ? null : _loadTask,
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: content,
        ),
      ),
    );
  }
}
