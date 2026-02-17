// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ============================================================================
  // CONFIGURATION
  // ============================================================================

  // ✅ UPDATE THIS WITH YOUR NGROK URL FROM COLAB
  // The URL should look like: https://abc123-34-87-60-105.ngrok-free.app
  // Copy ONLY the clean URL from CELL 14C output (no "NgrokTunnel:" prefix)
  static const String _baseUrl = "https://f724-34-87-60-105.ngrok-free.app";

  // Example: 'https://abc123.ngrok-free.app'

  // OR use local backend if running on same network
  // static const String _baseUrl = 'http://YOUR_LOCAL_IP:5000';
  // Example: 'http://192.168.1.100:5000'

  static const Duration _timeout = Duration(seconds: 60);

  // ============================================================================
  // API ENDPOINTS
  // ============================================================================

  /// Check if API is healthy
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/health'),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          // Fixed: Just check if status is healthy (removed model_loaded check)
          bool isHealthy = data['status'] == 'healthy';
          print('✅ Health check: $isHealthy');
          return isHealthy;
        } catch (e) {
          // If JSON parsing fails but status is 200, consider it healthy
          print('⚠️  Health check JSON parse error, but status 200: $e');
          return true;
        }
      }
      print('❌ Health check failed with status: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Health check error: $e');
      return false;
    }
  }

  /// Get API information
  Future<Map<String, dynamic>?> getApiInfo() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/info'),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('API info error: $e');
      return null;
    }
  }

  /// Get diagnosis for crop disease
  Future<DiagnosisResponse> getDiagnosis({
    required String query,
    String? sessionId,
  }) async {
    try {
      final body = {
        'query': query,
        if (sessionId != null) 'session_id': sessionId,
      };

      print('📤 Sending query: $query');
      print('📍 Base URL: $_baseUrl');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/diagnose'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body.substring(0, 100)}...');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return DiagnosisResponse(
          success: true,
          query: data['query'],
          response: data['response'],
          sessionId: data['session_id'],
          timestamp: DateTime.parse(data['timestamp']),
        );
      } else {
        String errorMsg = data['error'] ?? 'Unknown error from API';
        print('❌ API Error: $errorMsg');
        return DiagnosisResponse(
          success: false,
          query: query,
          error: errorMsg,
          timestamp: DateTime.now(),
        );
      }
    } catch (e) {
      print('❌ Diagnosis error: $e');
      return DiagnosisResponse(
        success: false,
        query: query,
        error: 'Connection error: ${e.toString()}',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Get conversation history
  Future<List<ChatMessage>?> getHistory(String sessionId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/history/$sessionId'),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messages = data['messages'] as List;

        return messages
            .map((msg) => ChatMessage(
                  role: msg['role'],
                  content: msg['content'],
                  timestamp: DateTime.parse(msg['timestamp']),
                ))
            .toList();
      }
      return null;
    } catch (e) {
      print('History error: $e');
      return null;
    }
  }

  /// Clear conversation history
  Future<bool> clearHistory(String sessionId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/clear-history/$sessionId'),
          )
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Clear history error: $e');
      return false;
    }
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

class DiagnosisResponse {
  final bool success;
  final String query;
  final String? response;
  final String? error;
  final String? sessionId;
  final DateTime timestamp;

  DiagnosisResponse({
    required this.success,
    required this.query,
    this.response,
    this.error,
    this.sessionId,
    required this.timestamp,
  });
}

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}
