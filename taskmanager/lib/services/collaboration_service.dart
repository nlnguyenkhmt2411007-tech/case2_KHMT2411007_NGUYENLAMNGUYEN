import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class CollaborationService {
  static const baseUrl = AuthService.baseUrl;
  static Future<Map<String, dynamic>> request(
    String method, String route, {Map<String, dynamic>? body}) async {
    final token = AuthService.accessToken;
    if (token == null || token.isEmpty) return {'success': false, 'message': 'Bạn cần đăng nhập'};
    try {
      final uri = Uri.parse('$baseUrl$route');
      final headers = <String,String>{
        'Authorization':'Bearer $token','Accept':'application/json','Content-Type':'application/json'
      };
      late http.Response response;
      switch(method) {
        case 'GET': response=await http.get(uri,headers:headers).timeout(const Duration(seconds:15));break;
        case 'POST': response=await http.post(uri,headers:headers,body:jsonEncode(body)).timeout(const Duration(seconds:15));break;
        case 'PUT': response=await http.put(uri,headers:headers,body:jsonEncode(body)).timeout(const Duration(seconds:15));break;
        case 'PATCH': response=await http.patch(uri,headers:headers,body:jsonEncode(body)).timeout(const Duration(seconds:15));break;
        case 'DELETE':response=await http.delete(uri,headers:headers).timeout(const Duration(seconds:15));break;
        default: throw StateError('Method invalid');
      }
      if(response.statusCode==401){AuthService.logout();return {'success':false,'message':'Phiên đăng nhập hết hạn'};}
      final data=jsonDecode(response.body);
      if(data is! Map<String,dynamic>) return {'success':false,'message':'Phản hồi máy chủ không hợp lệ'};
      return data;
    } catch (_) { return {'success':false,'message':'Không thể kết nối máy chủ'}; }
  }
  static Future<Map<String,dynamic>> team(String id)=>request('GET','/tasks/$id/team');
  static Future<Map<String,dynamic>> setPrimary(String id,String email)=>request('PUT','/tasks/$id/primary',body:{'email':email.trim()});
  static Future<Map<String,dynamic>> share(String id,List<String> emails,String role)=>request('PUT','/tasks/$id/shares',body:{'emails':emails,'role':role});
  static Future<Map<String,dynamic>> removeAssignee(String id,String userId)=>request('DELETE','/tasks/$id/assignees/$userId');
  static Future<Map<String,dynamic>> removeShare(String id,String userId)=>request('DELETE','/tasks/$id/shares/$userId');
}
