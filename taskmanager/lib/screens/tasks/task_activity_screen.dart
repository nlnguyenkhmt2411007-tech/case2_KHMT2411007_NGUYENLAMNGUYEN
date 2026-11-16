import 'package:flutter/material.dart';

import '../../services/task_service.dart';

class TaskActivityScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;

  const TaskActivityScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
  });

  @override
  State<TaskActivityScreen> createState() => _TaskActivityScreenState();
}

class _TaskActivityScreenState extends State<TaskActivityScreen> {
  static const primary = Color(0xFF2563EB);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await TaskService.getTaskActivities(widget.taskId);

    if (!mounted) return;

    if (result['success'] == true && result['data'] is List) {
      setState(() {
        _activities = (result['data'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _error = (result['message'] ?? 'Không thể tải lịch sử').toString();
      });
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'task_created':
        return 'Tạo công việc';
      case 'task_updated':
        return 'Chỉnh sửa công việc';
      case 'task_status_changed':
        return 'Thay đổi trạng thái';
      case 'task_completed':
        return 'Hoàn thành công việc';
      case 'task_assigned':
        return 'Giao công việc';
      case 'task_assignee_removed':
        return 'Thu hồi giao việc';
      case 'task_primary_changed':
        return 'Thay đổi người phụ trách chính';
      case 'task_shared':
        return 'Chia sẻ công việc';
      case 'task_share_permission_changed':
        return 'Thay đổi quyền chia sẻ';
      case 'task_share_removed':
        return 'Thu hồi quyền chia sẻ';
      default:
        return 'Hoạt động công việc';
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'task_created':
        return Icons.add_task;
      case 'task_completed':
        return Icons.task_alt;
      case 'task_assigned':
      case 'task_primary_changed':
        return Icons.group_add_outlined;
      case 'task_assignee_removed':
        return Icons.person_remove_outlined;
      case 'task_shared':
        return Icons.share_outlined;
      case 'task_share_permission_changed':
        return Icons.manage_accounts_outlined;
      case 'task_share_removed':
        return Icons.link_off_outlined;
      case 'task_status_changed':
        return Icons.sync_alt;
      default:
        return Icons.edit_note_outlined;
    }
  }

  String _formatTime(dynamic value) {
    final date = DateTime.tryParse((value ?? '').toString());
    if (date == null) return 'Không rõ thời gian';

    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/${local.year} - $hour:$minute';
  }

  String _actorName(Map<String, dynamic> activity) {
    final actor = activity['actorId'];

    if (actor is Map) {
      for (final key in ['fullName', 'name', 'email']) {
        final value = actor[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }

    return 'Thành viên hệ thống';
  }

  Widget _activityCard(Map<String, dynamic> activity, bool isLast) {
    final action = (activity['action'] ?? '').toString();
    final description = (activity['description'] ?? '').toString().trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_actionIcon(action), color: primary, size: 22),
            ),
            if (!isLast)
              Container(width: 2, height: 90, color: const Color(0xFFDBEAFE)),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _actionLabel(action),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description.isEmpty ? 'Đã cập nhật công việc' : description,
                  style: const TextStyle(color: Color(0xFF475569)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline, size: 16),
                        const SizedBox(width: 5),
                        Flexible(child: Text(_actorName(activity))),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 16),
                        const SizedBox(width: 5),
                        Text(_formatTime(activity['createdAt'])),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _loadActivities,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_activities.isEmpty) {
      return const Center(
        child: Text('Công việc này chưa có lịch sử hoạt động'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActivities,
      child: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: _activities.length,
        itemBuilder: (context, index) =>
            _activityCard(_activities[index], index == _activities.length - 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Lịch sử hoạt động'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Làm mới lịch sử',
            onPressed: _loading ? null : _loadActivities,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Text(
              widget.taskTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }
}
