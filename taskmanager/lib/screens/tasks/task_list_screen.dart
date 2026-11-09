import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/task_service.dart';
import '../profile/profile_screen.dart';
import 'create_task_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  static const Color primaryColor = Color(0xFF2563EB);
  static const Color textColor = Color(0xFF0F172A);
  static const Color mutedColor = Color(0xFF64748B);

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _primaryEmailController = TextEditingController();

  Timer? _searchTimer;

  bool _loading = true;
  bool _filterLoading = false;
  String? _error;

  int _requestId = 0;

  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _allTasks = [];

  // =====================================================
  // B6. BỘ LỌC VÀ SẮP XẾP
  // =====================================================

  String _scope = 'all';
  String _selectedStatus = '';
  String _selectedPriority = '';
  String _sortBy = 'createdAt';
  String _order = 'desc';

  bool get _hasFilters {
    return _primaryEmailController.text.trim().isNotEmpty ||
        _scope != 'all' ||
        _searchController.text.trim().isNotEmpty ||
        _selectedStatus.isNotEmpty ||
        _selectedPriority.isNotEmpty ||
        _sortBy != 'createdAt' ||
        _order != 'desc';
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _primaryEmailController.dispose();
    super.dispose();
  }

  // =====================================================
  // B2 + B6. LẤY DANH SÁCH CÔNG VIỆC
  // =====================================================

  List<Map<String, dynamic>> _parseTasks(dynamic rawTasks) {
    if (rawTasks is! List) {
      return <Map<String, dynamic>>[];
    }

    return rawTasks
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;

    final requestId = ++_requestId;

    // Lưu bộ lọc tại thời điểm gửi yêu cầu.
    final keyword = _searchController.text.trim();
    final primaryEmail = _primaryEmailController.text.trim();
    final scope = _scope;
    final status = _selectedStatus;
    final priority = _selectedPriority;
    final sortBy = _sortBy;
    final order = _order;

    setState(() {
      _filterLoading = true;
      _error = null;
    });

    // Danh sách đầy đủ dành cho thẻ thống kê.
    final allResult = await TaskService.getTasks();

    if (!mounted || requestId != _requestId) return;

    if (allResult['success'] != true) {
      setState(() {
        _loading = false;
        _filterLoading = false;
        _error = (allResult['message'] ?? 'Không thể tải danh sách công việc')
            .toString();
      });
      return;
    }

    final allTasks = _parseTasks(allResult['tasks']);

    final hasActiveFilters =
        keyword.isNotEmpty ||
        primaryEmail.isNotEmpty ||
        scope != 'all' ||
        status.isNotEmpty ||
        priority.isNotEmpty ||
        sortBy != 'createdAt' ||
        order != 'desc';

    final filteredResult = hasActiveFilters
        ? await TaskService.getTasks(
            q: keyword,
            scope: scope,
            primaryEmail: primaryEmail.isEmpty ? null : primaryEmail,
            status: status.isEmpty ? null : status,
            priority: priority.isEmpty ? null : priority,
            sortBy: sortBy,
            order: order,
          )
        : allResult;

    if (!mounted || requestId != _requestId) return;

    if (filteredResult['success'] == true) {
      setState(() {
        _allTasks = allTasks;
        _tasks = _parseTasks(filteredResult['tasks']);
        _loading = false;
        _filterLoading = false;
        _error = null;
      });
    } else {
      setState(() {
        _loading = false;
        _filterLoading = false;
        _error =
            (filteredResult['message'] ??
                    'Không thể tìm kiếm hoặc lọc công việc')
                .toString();
      });
    }
  }

  // =====================================================
  // B6. TÌM KIẾM CÓ DEBOUNCE
  // =====================================================

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();

    setState(() {});

    _searchTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        _loadTasks();
      }
    });
  }

  void _onFilterChanged() {
    _searchTimer?.cancel();
    _loadTasks();
  }

  void _resetFilters() {
    _searchTimer?.cancel();

    _searchController.clear();
    _primaryEmailController.clear();

    setState(() {
      _scope = 'all';
      _selectedStatus = '';
      _selectedPriority = '';
      _sortBy = 'createdAt';
      _order = 'desc';
    });

    _loadTasks();
  }

  // =====================================================
  // B1. MỞ MÀN HÌNH TẠO CÔNG VIỆC
  // =====================================================

  Future<void> _openCreateTask() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CreateTaskScreen()));

    if (!mounted) return;

    if (created == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tạo công việc thành công'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadTasks();
    }
  }

  // =====================================================
  // B3 + B4 + B5. MỞ CHI TIẾT CÔNG VIỆC
  // =====================================================

  Future<void> _openTaskDetail(Map<String, dynamic> task) async {
    final taskId = (task['_id'] ?? '').toString();

    if (taskId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy ID công việc')),
      );
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: taskId)),
    );

    if (!mounted) return;

    // Đồng bộ danh sách sau khi sửa hoặc xóa.
    await _loadTasks();
  }

  // =====================================================
  // ĐỊNH DẠNG NGÀY
  // =====================================================

  String _formatDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'Chưa đặt hạn';
    }

    final raw = value.toString();

    if (raw.length < 10) {
      return 'Ngày không hợp lệ';
    }

    final date = DateTime.tryParse(raw.substring(0, 10));

    if (date == null) {
      return 'Ngày không hợp lệ';
    }

    String two(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  // =====================================================
  // TRẠNG THÁI CÔNG VIỆC
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
        return mutedColor;
      case 'dang_thuc_hien':
        return primaryColor;
      case 'da_hoan_thanh':
        return const Color(0xFF059669);
      default:
        return mutedColor;
    }
  }

  // =====================================================
  // MỨC ĐỘ ƯU TIÊN
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
        return 'Chưa xác định';
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'thap':
        return const Color(0xFF059669);
      case 'trung_binh':
        return const Color(0xFFD97706);
      case 'cao':
        return const Color(0xFFDC2626);
      default:
        return mutedColor;
    }
  }

  // =====================================================
  // NHÃN HIỂN THỊ
  // =====================================================

  Widget _tag({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // =====================================================
  // THẺ THỐNG KÊ
  // =====================================================

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: mutedColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // B6. CẤU HÌNH GIAO DIỆN DROPDOWN
  // =====================================================

  InputDecoration _filterDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
  // B6. THANH TÌM KIẾM VÀ BỘ LỌC
  // =====================================================

  Widget _buildB6Filters() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tìm kiếm và bộ lọc',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              if (_hasFilters)
                TextButton(
                  onPressed: _resetFilters,
                  child: const Text('Đặt lại'),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Tìm kiếm theo tên.
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            maxLength: 100,
            decoration: InputDecoration(
              hintText: 'Nhập tên công việc...',
              prefixIcon: const Icon(Icons.search),
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Xóa từ khóa',
                      onPressed: () {
                        _searchController.clear();
                        _searchTimer?.cancel();
                        setState(() {});
                        _loadTasks();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Lọc trạng thái và ưu tiên.
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('status_$_selectedStatus'),
                  initialValue: _selectedStatus,
                  isExpanded: true,
                  decoration: _filterDecoration('Trạng thái'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Tất cả')),
                    DropdownMenuItem(
                      value: 'chua_thuc_hien',
                      child: Text(
                        'Chưa thực hiện',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'dang_thuc_hien',
                      child: Text(
                        'Đang thực hiện',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'da_hoan_thanh',
                      child: Text(
                        'Đã hoàn thành',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _selectedStatus = value;
                    });

                    _onFilterChanged();
                  },
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('priority_$_selectedPriority'),
                  initialValue: _selectedPriority,
                  isExpanded: true,
                  decoration: _filterDecoration('Ưu tiên'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Tất cả')),
                    DropdownMenuItem(value: 'thap', child: Text('Thấp')),
                    DropdownMenuItem(
                      value: 'trung_binh',
                      child: Text('Trung bình'),
                    ),
                    DropdownMenuItem(value: 'cao', child: Text('Cao')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _selectedPriority = value;
                    });

                    _onFilterChanged();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Sắp xếp danh sách.
          DropdownButtonFormField<String>(
            key: ValueKey('sort_${_sortBy}_$_order'),
            initialValue: '${_sortBy}_$_order',
            isExpanded: true,
            decoration: _filterDecoration('Sắp xếp công việc'),
            items: const [
              DropdownMenuItem(
                value: 'createdAt_desc',
                child: Text('Ngày tạo: Mới nhất trước'),
              ),
              DropdownMenuItem(
                value: 'createdAt_asc',
                child: Text('Ngày tạo: Cũ nhất trước'),
              ),
              DropdownMenuItem(
                value: 'dueDate_asc',
                child: Text('Hạn hoàn thành: Gần nhất'),
              ),
              DropdownMenuItem(
                value: 'dueDate_desc',
                child: Text('Hạn hoàn thành: Xa nhất'),
              ),
              DropdownMenuItem(
                value: 'priority_desc',
                child: Text('Ưu tiên: Cao đến thấp'),
              ),
              DropdownMenuItem(
                value: 'priority_asc',
                child: Text('Ưu tiên: Thấp đến cao'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;

              final separator = value.lastIndexOf('_');

              if (separator <= 0) return;

              setState(() {
                _sortBy = value.substring(0, separator);
                _order = value.substring(separator + 1);
              });

              _onFilterChanged();
            },
          ),

          if (_filterLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 3, color: primaryColor),
          ],
        ],
      ),
    );
  }

  // =====================================================
  // THẺ CÔNG VIỆC
  // =====================================================

  Widget _taskCard(Map<String, dynamic> task) {
    final title = (task['title'] ?? 'Không có tiêu đề').toString();

    final description = (task['description'] ?? '').toString();

    final status = (task['status'] ?? '').toString();

    final priority = (task['priority'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openTaskDetail(task),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),

              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: mutedColor,
                  ),
                ),
              ],

              const SizedBox(height: 14),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _tag(text: _statusLabel(status), color: _statusColor(status)),
                  _tag(
                    text: 'Ưu tiên: ${_priorityLabel(priority)}',
                    color: _priorityColor(priority),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              const Divider(color: Color(0xFFE2E8F0)),

              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: mutedColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hạn: ${_formatDate(task['dueDate'])}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // TRẠNG THÁI KHÔNG CÓ CÔNG VIỆC
  // =====================================================

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            _hasFilters ? Icons.search_off_rounded : Icons.inbox_outlined,
            size: 52,
            color: const Color(0xFF94A3B8),
          ),

          const SizedBox(height: 14),

          Text(
            _hasFilters
                ? 'Không tìm thấy công việc phù hợp'
                : 'Chưa có công việc nào',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 6),

          Text(
            _hasFilters
                ? 'Hãy thử thay đổi từ khóa hoặc bộ lọc.'
                : 'Nhấn Thêm công việc để bắt đầu.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: mutedColor),
          ),

          if (_hasFilters) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh),
              label: const Text('Xóa bộ lọc'),
            ),
          ],
        ],
      ),
    );
  }

  // =====================================================
  // NỘI DUNG DANH SÁCH
  // =====================================================

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_outlined,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadTasks,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    // Thống kê từ toàn bộ công việc,
    // không bị thay đổi khi lọc danh sách.
    final inProgress = _allTasks
        .where((task) => task['status'] == 'dang_thuc_hien')
        .length;

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Tổng quan công việc',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Theo dõi và quản lý công việc của bạn.',
            style: TextStyle(fontSize: 13, color: mutedColor),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              _statCard(
                title: 'Tổng công việc',
                value: '${_allTasks.length}',
                icon: Icons.assignment_outlined,
                color: primaryColor,
              ),
              const SizedBox(width: 12),
              _statCard(
                title: 'Đang thực hiện',
                value: '$inProgress',
                icon: Icons.pending_actions_outlined,
                color: const Color(0xFFD97706),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // B6: TÌM KIẾM, LỌC, SẮP XẾP
          DropdownButtonFormField<String>(
            initialValue: _scope,
            decoration: const InputDecoration(
              labelText: 'Vai trò công việc',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('Tất cả công việc liên quan'),
              ),
              DropdownMenuItem(value: 'created', child: Text('Tôi tạo')),
              DropdownMenuItem(value: 'assigned', child: Text('Được giao')),
              DropdownMenuItem(
                value: 'primary',
                child: Text('Phụ trách chính'),
              ),
              DropdownMenuItem(value: 'shared', child: Text('Được chia sẻ')),
            ],
            onChanged: (v) {
              setState(() => _scope = v ?? 'all');
              _loadTasks();
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _primaryEmailController,
            decoration: InputDecoration(
              labelText: 'Lọc theo email người phụ trách chính',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _loadTasks,
              ),
            ),
            onSubmitted: (_) => _loadTasks(),
          ),
          const SizedBox(height: 14),
          _buildB6Filters(),

          const SizedBox(height: 24),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Danh sách công việc',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),

              IconButton(
                onPressed: _filterLoading ? null : _loadTasks,
                tooltip: 'Làm mới',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            'Hiển thị ${_tasks.length} công việc',
            style: const TextStyle(fontSize: 13, color: mutedColor),
          ),

          const SizedBox(height: 14),

          if (_tasks.isEmpty) _emptyState() else ..._tasks.map(_taskCard),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // =====================================================
  // MỞ TRANG CÁ NHÂN
  // =====================================================

  void _openProfile() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  // =====================================================
  // GIAO DIỆN CHÍNH
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Quản lý công việc',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _openProfile,
            tooltip: 'Thông tin cá nhân',
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: _buildContent(),

      // Nút tạo công việc cố định phía dưới.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 52),
            child: FilledButton.icon(
              onPressed: _openCreateTask,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm công việc'),
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
