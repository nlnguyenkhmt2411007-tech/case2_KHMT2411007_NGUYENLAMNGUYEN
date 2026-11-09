import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class TaskAssignmentService {
  static const String baseUrl = AuthService.baseUrl;

  // =====================================================
  // C1. GIAO CÔNG VIỆC CHO NHIỀU NGƯỜI BẰNG EMAIL
  // POST /api/tasks/:id/assignees
  // =====================================================

  static Future<Map<String, dynamic>> assignTask({
    required String taskId,
    required List<String> emails,
  }) async {
    final token = AuthService.accessToken;

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Bạn cần đăng nhập để giao công việc',
      };
    }

    if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(taskId)) {
      return {'success': false, 'message': 'ID công việc không hợp lệ'};
    }

    if (emails.isEmpty || emails.length > 20) {
      return {'success': false, 'message': 'Mỗi lần giao từ 1 đến 20 người'};
    }

    final normalizedEmails = emails
        .map((email) => email.trim().toLowerCase())
        .toList();

    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    for (final email in normalizedEmails) {
      if (email.isEmpty ||
          email.length > 254 ||
          !emailPattern.hasMatch(email)) {
        return {'success': false, 'message': 'Email không hợp lệ: $email'};
      }
    }

    if (normalizedEmails.toSet().length != normalizedEmails.length) {
      return {
        'success': false,
        'message': 'Danh sách email có người nhận bị trùng',
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/tasks/$taskId/assignees'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'emails': normalizedEmails}),
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
          'message': decoded['message'] ?? 'Giao công việc thành công',
          'taskId': decoded['taskId'],
          'totalAssignees': decoded['totalAssignees'],
          'assignees': decoded['assignees'] ?? <dynamic>[],
        };
      }

      return {
        'success': false,
        'message': decoded['message'] ?? 'Không thể giao công việc',
        'missingEmails': decoded['missingEmails'],
        'duplicateEmails': decoded['duplicateEmails'],
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Không thể kết nối đến máy chủ. Vui lòng thử lại.',
      };
    }
  }
}
