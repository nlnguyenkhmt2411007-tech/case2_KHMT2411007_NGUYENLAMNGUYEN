import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class NotificationService {
  static Future<Map<String, dynamic>> getNotifications() async {
    final token = AuthService.accessToken;
    if (token == null || token.isEmpty) {
      return {'success': false, 'message': 'Bạn cần đăng nhập để xem thông báo'};
    }

    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/notifications'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return {'success': false, 'message': 'Phản hồi API không hợp lệ'};
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }
      return {
        'success': false,
        'message': decoded['message']?.toString() ?? 'Không thể tải thông báo',
      };
    } catch (_) {
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ'};
    }
  }

  static Future<Map<String, dynamic>> markAsRead(String notificationId) async {
    final token = AuthService.accessToken;
    if (token == null || token.isEmpty) {
      return {'success': false, 'message': 'Bạn cần đăng nhập để tiếp tục'};
    }
    if (notificationId.isEmpty) {
      return {'success': false, 'message': 'ID thông báo không hợp lệ'};
    }

    try {
      final response = await http.patch(
        Uri.parse('${AuthService.baseUrl}/notifications/${Uri.encodeComponent(notificationId)}/read'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return {'success': false, 'message': 'Phản hồi API không hợp lệ'};
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }
      return {
        'success': false,
        'message': decoded['message']?.toString() ?? 'Không thể đánh dấu đã đọc',
      };
    } catch (_) {
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ'};
    }
  }
}
