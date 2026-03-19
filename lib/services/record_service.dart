import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:afpflutter/services/api_config.dart';
import 'package:afpflutter/services/authentication.dart';

class RecordService {
  RecordService({AuthenticationService? authService})
      : _authService = authService ?? AuthenticationService();

  final AuthenticationService _authService;

  Future<Map<String, dynamic>> createRecordFromScan({
    required String customerId,
    required String type,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated. Please login again.');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/record/create');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'customer_id': customerId,
        'type': type,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return data;
    }
    final errorMsg =
        data['detail'] ?? data['message'] ?? 'Failed to create scan record.';
    throw Exception(errorMsg.toString());
  }
}
