import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

/// Thrown when the server ends the session because OTP must be re-entered (7-day policy).
class OtpReverificationRequired implements Exception {
  OtpReverificationRequired([this.message = 'Please sign in again and enter your authenticator code.']);
  final String message;
  @override
  String toString() => message;
}

class AuthenticationService {
  static String get baseUrl =>
      ApiConfig.baseUrl; // use current backend chosen in ApiConfig
  static const String _tokenKey = 'jwt_token';

  // Login method - returns response with status code
  Future<Map<String, dynamic>> login(String email, String password) async {
    // Build the full URL for debugging
    final url = Uri.parse('$baseUrl/user/login');
    print('🔵 Making login request to: $url'); // Debug: Print the URL being called
    
    try {
      // Make the HTTP POST request
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json', // Tell server we're sending JSON
        },
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      );

      // Debug: Print response details
      print('🟢 Response status: ${response.statusCode}'); // Debug: Print status code
      print('🟢 Response body: ${response.body}'); // Debug: Print response body

      // Try to decode JSON response
      Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (jsonError) {
        // If JSON decode fails, throw error with response body
        throw Exception('Invalid JSON response: ${response.body}');
      }

      // Handle 200 — may include a token only when the endpoint issues one (e.g. not used after password-only login).
      if (response.statusCode == 200) {
        // Store JWT token if present
        if (responseData['token'] != null) {
          await _saveToken(responseData['token']);
        }
        return responseData;
      }
      // Handle 202 - Legacy/alternate "OTP required" HTTP status (no token stored here).
      else if (response.statusCode == 202) {
        return responseData;
      }
      // Handle 401 - Invalid credentials
      else if (response.statusCode == 401) {
        // Extract error message from response if available
        final errorMsg = responseData['detail'] ?? 'Invalid credentials';
        throw Exception(errorMsg);
      }
      // Handle other HTTP errors (400, 500, etc.)
      else {
        // Extract error message from response if available
        final errorMsg = responseData['detail'] ?? 
                        responseData['message'] ?? 
                        'Server error: ${response.statusCode}';
        throw Exception(errorMsg);
      }
    } on http.ClientException catch (e) {
      // Handle network errors (connection refused, timeout, etc.)
      print('🔴 Network error: $e'); // Debug: Print network error
      throw Exception('Network error: Unable to connect to server. ${e.message}');
    } on FormatException catch (e) {
      // Handle JSON decode errors
      print('🔴 JSON decode error: $e'); // Debug: Print JSON error
      throw Exception('Invalid response from server: $e');
    } catch (e) {
      // Handle any other errors
      print('🔴 Login error: $e'); // Debug: Print any other error
      rethrow; // Re-throw to preserve original error details
    }
  }

  // Verify OTP method
  Future<Map<String, dynamic>> verifyOTP(String email, String otpCode) async {
    // Build the full URL for debugging
    final url = Uri.parse('$baseUrl/user/verify-otp');
    print('🔵 Making OTP verification request to: $url'); // Debug: Print the URL
    
    try {
      // Make the HTTP POST request
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json', // Tell server we're sending JSON
        },
        body: jsonEncode({
          'email': email.trim(),
          'otp_code': otpCode.trim(),
        }),
      );

      // Debug: Print response details
      print('🟢 Response status: ${response.statusCode}'); // Debug: Print status code
      print('🟢 Response body: ${response.body}'); // Debug: Print response body

      // Try to decode JSON response
      Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (jsonError) {
        // If JSON decode fails, throw error with response body
        throw Exception('Invalid JSON response: ${response.body}');
      }

      // Handle 200 - OTP verified successfully
      if (response.statusCode == 200) {
        // Store JWT token if present
        if (responseData['token'] != null) {
          await _saveToken(responseData['token']);
        }
        return responseData;
      }
      // Handle 401 - Invalid OTP code
      else if (response.statusCode == 401) {
        // Extract error message from response if available
        final errorMsg = responseData['detail'] ?? 'Invalid OTP code';
        throw Exception(errorMsg);
      }
      // Handle other HTTP errors
      else {
        // Extract error message from response if available
        final errorMsg = responseData['detail'] ?? 
                        responseData['message'] ?? 
                        'Server error: ${response.statusCode}';
        throw Exception(errorMsg);
      }
    } on http.ClientException catch (e) {
      // Handle network errors (connection refused, timeout, etc.)
      print('🔴 Network error: $e'); // Debug: Print network error
      throw Exception('Network error: Unable to connect to server. ${e.message}');
    } on FormatException catch (e) {
      // Handle JSON decode errors
      print('🔴 JSON decode error: $e'); // Debug: Print JSON error
      throw Exception('Invalid response from server: $e');
    } catch (e) {
      // Handle any other errors
      print('🔴 OTP verification error: $e'); // Debug: Print any other error
      rethrow; // Re-throw to preserve original error details
    }
  }

  // Save JWT token to local storage
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Get stored JWT token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Clear stored token (logout)
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Clears JWT and throws [OtpReverificationRequired] when the API signals 7-day OTP re-verify.
  Future<void> throwIfOtpReverifyResponse(
    http.Response response,
    Map<String, dynamic> data,
  ) async {
    if (response.statusCode != 401) return;
    final detail = data['detail'];
    if (detail is Map && detail['code'] == 'OTP_REVERIFY_REQUIRED') {
      await clearToken();
      final msg = detail['message'] as String? ??
          'Authenticator must be re-verified at least every 7 days. Please log in again.';
      throw OtpReverificationRequired(msg);
    }
  }

  Future<Map<String, String>> _buildAuthHeaders() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated. Please login again.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Fetch authenticated user profile
  Future<Map<String, dynamic>> getProfile() async {
    final url = Uri.parse('$baseUrl/user/profile');
    final headers = await _buildAuthHeaders();
    final response = await http.get(url, headers: headers);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await throwIfOtpReverifyResponse(response, data);
    if (response.statusCode == 200) {
      return data;
    }
    final errorMsg = data['detail'] ?? data['message'] ?? 'Failed to load profile';
    throw Exception(errorMsg);
  }

  // Update authenticated user profile
  Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    String image = '',
    bool? otpEnabled,
  }) async {
    final url = Uri.parse('$baseUrl/user/profile');
    final headers = await _buildAuthHeaders();
    final body = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      'image': image,
    };
    if (otpEnabled != null) {
      body['otp_enabled'] = otpEnabled;
    }
    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(body),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await throwIfOtpReverifyResponse(response, data);
    if (response.statusCode == 200) {
      return data;
    }
    final errorMsg = data['detail'] ?? data['message'] ?? 'Failed to update profile';
    throw Exception(errorMsg);
  }

  /// Optional OTP enrollment after login (Yes / No thanks on modal).
  Future<Map<String, dynamic>> submitOtpSetupPromptAccepted(bool accepted) async {
    final url = Uri.parse('$baseUrl/user/otp-setup-response');
    final headers = await _buildAuthHeaders();
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'accepted': accepted}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await throwIfOtpReverifyResponse(response, data);
    if (response.statusCode == 200) {
      return data;
    }
    final errorMsg = data['detail'] ?? data['message'] ?? 'Request failed';
    throw Exception(errorMsg);
  }
}