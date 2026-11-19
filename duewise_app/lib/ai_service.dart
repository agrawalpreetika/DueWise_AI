import 'dart:convert';

import 'package:http/http.dart' as http;

class AiService {
  static const String _backendUrl = String.fromEnvironment(
    'AI_BACKEND_URL',
    defaultValue: 'https://duewise-ai.onrender.com/api/chat',
  );

  Future<Map<String, dynamic>?> sendMessageToAgent(String userMessage) async {
    try {
      final response = await http
          .post(
            Uri.parse(_backendUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'message': userMessage}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data; // Returns full map containing type, data, and response message
      }
    } catch (e) {
      print("Connection Error: $e");
    }
    return null;
  }
}
