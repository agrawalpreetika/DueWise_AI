import 'dart:convert';

import 'package:http/http.dart' as http;

class AiService {
  static const String _backendUrl = String.fromEnvironment(
    'AI_BACKEND_URL',
    defaultValue: 'https://localhost:8000/api/chat', // Default to localhost for development
  );

  Future<Map<String, dynamic>?> sendMessageToAgent(
    String userMessage, {
    List<Map<String, dynamic>> history = const [],
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_backendUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'message': userMessage, 'history': history}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data as Map<String, dynamic>;
      }
    } catch (e) {
      print("Connection Error: $e");
    }
    return null;
  }
}
