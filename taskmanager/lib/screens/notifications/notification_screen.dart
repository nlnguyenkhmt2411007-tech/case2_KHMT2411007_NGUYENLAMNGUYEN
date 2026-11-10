import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../tasks/task_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const Color _blue = Color(0xFF2563EB);
  bool _loading = true;
  String? _error;
  int _unreadCount = 0;
  List<Map<String, dynamic>> _notifications = [];
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await NotificationService.getNotifications();
    if (!mounted) return;
    if (result['success'] == true) {
      final items = result['notifications'];
      setState(() {
        _notifications = items is List
            ? items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        _unreadCount = (result['unreadCount'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _error = result['message']?.toString() ?? 'Không thể tải thông báo';
      });
    }
  }

  String _dateLabel(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'task_shared':
        return Icons.people_outline;
      case 'task_status_changed':
        return Icons.sync_alt;
      default:
        return Icons.assignment_ind_outlined;
    }
  }

  Future<void> _openNotification(Map<String, dynamic> item) async {
    final id = item['_id']?.toString() ?? '';
    if (id.isEmpty || _processing.contains(id)) return;
    setState(() => _processing.add(id));

    if (item['isRead'] != true) {
      final result = await NotificationService.markAsRead(id);
      if (!mounted) return;
      if (result['success'] != true) {
        setState(() => _processing.remove(id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? 'Không thể đánh dấu đã đọc')),
        );
        return;
      }
      setState(() {
        item['isRead'] = true;
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
      });
    }
    if (!mounted) return;
    setState(() => _processing.remove(id));

    final task = item['taskId'];
    final taskId = task is Map ? task['_id']?.toString() : task?.toString();
    if (taskId == null || taskId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Công việc liên quan không còn khả dụng')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: taskId)),
    );
    if (mounted) await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Thông báo', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadNotifications,
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _loadNotifications, child: const Text('Thử lại')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Chưa đọc: $_unreadCount',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: _blue)),
                      const SizedBox(height: 14),
                      if (_notifications.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 70),
                          child: Center(child: Text('Bạn chưa có thông báo nào')),
                        )
                      else
                        ..._notifications.map((item) {
                          final id = item['_id']?.toString() ?? '';
                          final isUnread = item['isRead'] != true;
                          final type = item['type']?.toString() ?? '';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: isUnread ? const Color(0xFFEFF6FF) : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(14),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFDBEAFE),
                                child: Icon(_typeIcon(type), color: _blue),
                              ),
                              title: Text(
                                item['title']?.toString() ?? 'Thông báo',
                                style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.w500),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Text(item['message']?.toString() ?? ''),
                                  const SizedBox(height: 8),
                                  Text(_dateLabel(item['createdAt']),
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                ],
                              ),
                              trailing: _processing.contains(id)
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : isUnread
                                      ? const Icon(Icons.circle, color: _blue, size: 11)
                                      : const Icon(Icons.chevron_right),
                              onTap: () => _openNotification(item),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
