import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class TaskService {
  static const String baseUrl = AuthService.baseUrl;

  // =====================================================
  // B2 + B6. DANH SÁCH, TÌM KIẾM, LỌC, SẮP XẾP
  // GET /api/tasks
  // =====================================================

  static Future<Map<String, dynamic>> getTasks({
    String q = '',
    String? status,
    String? priority,
    String sortBy = 'createdAt',
    String order = 'desc',
  }) async {
    final token = AuthService.accessToken;

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Bạn cần đăng nhập để xem công việc',
        'tasks': <dynamic>[],
      };
    }

    const validStatuses = ['chua_thuc_hien', 'dang_thuc_hien', 'da_hoan_thanh'];

    const validPriorities = ['thap', 'trung_binh', 'cao'];

    if (q.trim().length > 100) {
      return {
        'success': false,
        'message': 'Từ khóa tìm kiếm không quá 100 ký tự',
        'tasks': <dynamic>[],
      };
    }

    if (status != null && !validStatuses.contains(status)) {
      return {
        'success': false,
        'message': 'Bộ lọc trạng thái không hợp lệ',
        'tasks': <dynamic>[],
      };
    }

    if (priority != null && !validPriorities.contains(priority)) {
      return {
        'success': false,
        'message': 'Bộ lọc ưu tiên không hợp lệ',
        'tasks': <dynamic>[],
      };
    }

    if (!['createdAt', 'dueDate', 'priority'].contains(sortBy)) {
      return {
        'success': false,
        'message': 'Trường sắp xếp không hợp lệ',
        'tasks': <dynamic>[],
      };
    }

    if (order != 'asc' && order != 'desc') {
      return {
        'success': false,
        'message': 'Thứ tự sắp xếp không hợp lệ',
        'tasks': <dynamic>[],
      };
    }

    final parameters = <String, String>{'sortBy': sortBy, 'order': order};

    if (q.trim().isNotEmpty) {
      parameters['q'] = q.trim();
    }

    if (status != null) {
      parameters['status'] = status;
    }

    if (priority != null) {
      parameters['priority'] = priority;
    }

    final uri = Uri.parse('$baseUrl/tasks')
        .replace(queryParameters: parameters);

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Dữ liệu trả về không hợp lệ');
      }

      if (response.statusCode == 401) {
        AuthService.logout();
        return {
          'success': false,
          'message': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          'tasks': <dynamic>[],
        };
      }

      if (response.statusCode == 200 && decoded['success'] == true) {
        final tasks = decoded['tasks'];

        if (tasks is! List) {
          return {
            'success': false,
            'message': 'Danh sách công việc không hợp lệ',
            'tasks': <dynamic>[],
          };
        }

        return {
          'success': true,
          'message': decoded['message'] ?? 'Lấy danh sách công việc thành công',
          'total': decoded['total'] ?? tasks.length,
          'tasks': tasks,
        };
      }

      return {
        'success': false,
        'message': decoded['message'] ?? 'Không thể tải công việc',
        'tasks': <dynamic>[],
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Không thể kết nối đến máy chủ. Vui lòng thử lại.',
        'tasks': <dynamic>[],
      };
    }
  }

  // =====================================================
  // B1. TẠO CÔNG VIỆC
  // POST /api/tasks
  // =====================================================

  static Future<Map<String, dynamic>> createTask({
    required String title,
    String description = '',
    String status = 'chua_thuc_hien',
    String priority = 'trung_binh',
    DateTime? startDate,
    DateTime? dueDate,
  }) async {
    final token = AuthService.accessToken;

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Bạn cần đăng nhập để tạo công việc',
      };
    }

    final normalizedTitle = title.trim();

    if (normalizedTitle.length < 2 || normalizedTitle.length > 200) {
      return {
        'success': false,
        'message': 'Tên công việc phải có từ 2 đến 200 ký tự',
      };
    }

    if (description.trim().length > 5000) {
      return {
        'success': false,
        'message': 'Mô tả không được vượt quá 5000 ký tự',
      };
    }

    if (startDate != null && dueDate != null && dueDate.isBefore(startDate)) {
      return {
        'success': false,
        'message': 'Hạn hoàn thành không được trước ngày bắt đầu',
      };
    }

    String? formatDate(DateTime? date) {
      if (date == null) return null;

      final year = date.year.toString().padLeft(4, '0');
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');

      return '$year-$month-$day';
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/tasks'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'title': normalizedTitle,
              'description': description.trim(),
              'status': status,
              'priority': priority,
              'startDate': formatDate(startDate),
              'dueDate': formatDate(dueDate),
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Dữ liệu trả về không hợp lệ');
      }

      if (response.statusCode == 201 && decoded['success'] == true) {
        return decoded;
      }

      if (response.statusCode == 401) {
        AuthService.logout();
        return {
          'success': false,
          'message': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        };
      }

      return {
        'success': false,
        'message': decoded['message'] ?? 'Không thể tạo công việc',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Không thể kết nối đến máy chủ. Vui lòng thử lại.',
      };
    }
  }

  // =====================================================
  // B3. XEM CHI TIẾT
  // GET /api/tasks/:id
  // =====================================================

  static Future<Map<String, dynamic>> getTaskById(String taskId) async {
    final token = AuthService.accessToken;

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Bạn cần đăng nhập để xem công việc',
      };
    }

    if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(taskId)) {
      return {'success': false, 'message': 'ID công việc không hợp lệ'};
    }

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/tasks/$taskId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Dữ liệu trả về không hợp lệ');
      }

      if (response.statusCode == 200 && decoded['success'] == true) {
        final task = decoded['task'];

        if (task is! Map) {
          return {
            'success': false,
            'message': 'Dữ liệu công việc không hợp lệ',
          };
        }

        return {
          'success': true,
          'message': decoded['message'] ?? 'Lấy chi tiết công việc thành công',
          'task': Map<String, dynamic>.from(task),
        };
      }

      if (response.statusCode == 401) {
        AuthService.logout();
        return {
          'success': false,
          'message': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        };
      }

      return {
        'success': false,
        'message': decoded['message'] ?? 'Không thể lấy chi tiết công việc',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Không thể kết nối đến máy chủ. Vui lòng thử lại.',
      };
    }
  }

  // =====================================================
  // B4. CHỈNH SỬA
  // PATCH /api/tasks/:id
  // =====================================================

  static Future<Map<String, dynamic>> updateTask({
    required String taskId,
    required String title,
    required String description,
    required String status,
    required String priority,
    DateTime? startDate,
    DateTime? dueDate,
  }) async {
    final token = AuthService.accessToken;

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Bạn cần đăng nhập để chỉnh sửa công việc',
      };
    }

    if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(taskId)) {
      return {'success': false, 'message': 'ID công việc không hợp lệ'};
    }

    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();

    if (normalizedTitle.length < 2 || normalizedTitle.length > 200) {
      return {
        'success': false,
        'message': 'Tên công việc phải có từ 2 đến 200 ký tự',
      };
    }

    if (normalizedDescription.length > 5000) {
      return {
        'success': false,
        'message': 'Mô tả không được vượt quá 5000 ký tự',
      };
    }

    const statuses = ['chua_thuc_hien', 'dang_thuc_hien', 'da_hoan_thanh'];

    if (!statuses.contains(status)) {
      return {'success': false, 'message': 'Trạng thái công việc không hợp lệ'};
    }

    if (!['thap', 'trung_binh', 'cao'].contains(priority)) {
      return {'success': false, 'message': 'Mức độ ưu tiên không hợp lệ'};
    }

    if (startDate != null && dueDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);

      final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

      if (due.isBefore(start)) {
        return {
          'success': false,
          'message': 'Hạn hoàn thành không được trước ngày bắt đầu',
        };
      }
    }

    String? formatDate(DateTime? date) {
      if (date == null) return null;

      final year = date.year.toString().padLeft(4, '0');
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');

      return '$year-$month-$day';
    }

    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/tasks/$taskId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'title': normalizedTitle,
              'description': normalizedDescription,
              'status': status,
              'priority': priority,
              'startDate': formatDate(startDate),
              'dueDate': formatDate(dueDate),
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Phản hồi máy chủ không hợp lệ');
      }

      if (response.statusCode == 401) {
        AuthService.logout();
        return {
          'success': false,
          'message': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        };
      }

      if (response.statusCode == 200 && decoded['success'] == true) {
        final task = decoded['task'];

        if (task is! Map) {
          return {
            'success': false,
            'message': 'Dữ liệu công việc cập nhật không hợp lệ',
          };
        }

        return {
          'success': true,
          'message': decoded['message'] ?? 'Cập nhật công việc thành công',
          'task': Map<String, dynamic>.from(task),
        };
      }

      return {
        'success': false,
        'message': decoded['message'] ?? 'Không thể cập nhật công việc',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Không thể kết nối đến máy chủ. Vui lòng thử lại.',
      };
    }
  }

  // =====================================================
  // B5. XÓA CÔNG VIỆC
  // DELETE /api/tasks/:id
  // =====================================================

  static Future<Map<String, dynamic>> deleteTask(String taskId) async {
    final token = AuthService.accessToken;

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Bạn cần đăng nhập để xóa công việc',
      };
    }

    if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(taskId)) {
      return {'success': false, 'message': 'ID công việc không hợp lệ'};
    }

    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/tasks/$taskId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Phản hồi máy chủ không hợp lệ');
      }

      if (response.statusCode == 401) {
        AuthService.logout();
        return {
          'success': false,
          'message': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        };
      }

      if (response.statusCode == 200 && decoded['success'] == true) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Xóa công việc thành công',
          'taskId': decoded['taskId'] ?? taskId,
        };
      }

      return {
        'success': false,
        'message': decoded['message'] ?? 'Không thể xóa công việc',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Không thể kết nối đến máy chủ. Vui lòng thử lại.',
      };
    }
  }
}
