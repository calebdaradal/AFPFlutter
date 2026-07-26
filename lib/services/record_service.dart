import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:afpflutter/services/api_config.dart';
import 'package:afpflutter/services/authentication.dart';

class RecordService {
  RecordService({AuthenticationService? authService})
      : _authService = authService ?? AuthenticationService();

  final AuthenticationService _authService;

  Future<Map<String, dynamic>> createRecordFromScan({
    required String passcardId, // changed: scan ids now come from passcards collection
    required String type, // unchanged: IN/OUT
    required double longitude, // added: scanner longitude for backend SNS payload
    required double latitude, // added: scanner latitude for backend SNS payload
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
        'passcard_id': passcardId, // changed: backend expects passcard_id
        'type': type, // unchanged: IN/OUT
        'longitude': longitude, // added: send scanner longitude to backend
        'latitude': latitude, // added: send scanner latitude to backend
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await _authService.throwIfOtpReverifyResponse(response, data);
    if (response.statusCode == 200) {
      return data;
    }
    final errorMsg =
        data['detail'] ?? data['message'] ?? 'Failed to create scan record.';
    throw Exception(errorMsg.toString());
  }
}
