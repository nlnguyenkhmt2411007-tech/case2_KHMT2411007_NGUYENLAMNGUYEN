import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthService {
  // Android Emulator truy cập backend Node.js trên máy tính.
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  // JWT hiện chỉ lưu tạm trong bộ nhớ.
  static String? _accessToken;

  static bool get isLoggedIn =>
      _accessToken != null && _accessToken!.isNotEmpty;

  // =====================================================
  // 1. ĐĂNG KÝ TÀI KHOẢN
  // POST /api/auth/register
  // =====================================================

  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fullName': fullName.trim(),
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Phản hồi API không hợp lệ');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      return {
        'success': false,
        'message': decoded['message'] ?? 'Đăng ký thất bại',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Không thể kết nối đến máy chủ. Vui lòng thử lại.',
      };
    }
  }

  // =====================================================
  // 2. ĐĂNG NHẬP
  // POST /api/auth/login
  // =====================================================

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Phản hồi API không hợp lệ');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final token = decoded['token'];

        if (token is! String || token.isEmpty) {
          return {
            'success': false,
            'message': 'Máy chủ không trả về JWT hợp lệ',
          };
        }

        _accessToken = token;

        return decoded;
      }

      return {
        'success': false,
        'message': decoded['message'] ?? 'Đăng nhập thất bại',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Không thể kết nối đến máy chủ. Vui lòng thử lại.',
      };
    }
  }

  // =====================================================
  // 3. XEM THÔNG TIN CÁ NHÂN
  // GET /api/auth/me
  // =====================================================

  static Future<Map<String, dynamic>> getMe() async {
    if (!isLoggedIn) {
      return {'success': false, 'message': 'Bạn cần đăng nhập để tiếp tục'};
    }

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/auth/me'),
            headers: {'Authorization': 'Bearer $_accessToken'},
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Phản hồi API không hợp lệ');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      if (response.statusCode == 401) {
        _accessToken = null;
      }

      return {
        'success': false,
        'message': decoded['message'] ?? 'Không thể lấy thông tin cá nhân',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Không thể kết nối đến máy chủ. Vui lòng thử lại.',
      };
    }
  }

  // =====================================================
  // 4. CẬP NHẬT THÔNG TIN CÁ NHÂN
  // PATCH /api/auth/me
  // =====================================================

  static Future<Map<String, dynamic>> updateMe({
    required String fullName,
  }) async {
    if (!isLoggedIn) {
      return {
        'success': false,
        'message': 'Bạn cần đăng nhập để cập nhật thông tin',
      };
    }

    final name = fullName.trim();

    if (name.length < 2 || name.length > 100) {
      return {
        'success': false,
        'message': 'Họ và tên phải có từ 2 đến 100 ký tự',
      };
    }

    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/auth/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_accessToken',
            },
            body: jsonEncode({'fullName': name}),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Phản hồi API không hợp lệ');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      if (response.statusCode == 401) {
        _accessToken = null;
      }

      return {
        'success': false,
        'message': decoded['message'] ?? 'Không thể cập nhật thông tin cá nhân',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Không thể kết nối đến máy chủ. Vui lòng thử lại.',
      };
    }
  }

  // =====================================================
  // 5. ĐỔI MẬT KHẨU
  // PATCH /api/auth/change-password
  // =====================================================

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!isLoggedIn) {
      return {'success': false, 'message': 'Bạn cần đăng nhập để đổi mật khẩu'};
    }

    if (currentPassword.isEmpty || newPassword.isEmpty) {
      return {'success': false, 'message': 'Vui lòng nhập đầy đủ mật khẩu'};
    }

    if (newPassword.length < 8) {
      return {
        'success': false,
        'message': 'Mật khẩu mới phải có ít nhất 8 ký tự',
      };
    }

    if (currentPassword == newPassword) {
      return {
        'success': false,
        'message': 'Mật khẩu mới phải khác mật khẩu hiện tại',
      };
    }

    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/auth/change-password'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_accessToken',
            },
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Phản hồi API không hợp lệ');
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded['success'] == true) {
        // Xóa JWT trên thiết bị sau khi đổi mật khẩu.
        // Giao diện sẽ yêu cầu người dùng đăng nhập lại.
        _accessToken = null;

        return decoded;
      }

      if (response.statusCode == 401) {
        _accessToken = null;
      }

      return {
        'success': false,
        'message': decoded['message'] ?? 'Không thể đổi mật khẩu',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Không thể kết nối đến máy chủ. Vui lòng thử lại.',
      };
    }
  }

  // =====================================================
  // 6. ĐĂNG XUẤT
  // =====================================================

  static void logout() {
    _accessToken = null;
  }
}
