import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenRouterService {
  static final String apiKey = dotenv.env['OPENROUTER_API_KEY'] ?? '';
  static const String baseUrl = 'https://openrouter.ai/api/v1';

  OpenRouterService() {
    if (apiKey.isEmpty) {
      print(
          '[OpenRouterService] Warning: OPENROUTER_API_KEY is missing or empty');
    } else {
      print('[OpenRouterService] API key loaded: ${apiKey.substring(0, 8)}...');
    }
  }

  Future<String> analyzeImage(String imageUrl, String prompt) async {
    if (apiKey.isEmpty) {
      throw Exception('API key is missing. Please configure .env file.');
    }

    final url = Uri.parse('$baseUrl/chat/completions');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json; charset=utf-8',
      'HTTP-Referer': 'https://smart-wearable-app.example.com',
      'X-Title': 'Smart Wearable App',
    };

    final body = jsonEncode({
      'model': 'meta-llama/llama-4-maverick:free',
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {'url': imageUrl}
            }
          ]
        }
      ]
    });

    try {
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 60), onTimeout: () {
        throw Exception('Request timed out');
      });

      print('[OpenRouterService] Response status: ${response.statusCode}');
      final decodedBody = utf8.decode(response.bodyBytes);
      print('[OpenRouterService] Response body: $decodedBody');

      switch (response.statusCode) {
        case 200:
          final jsonData = jsonDecode(decodedBody);
          return jsonData['choices'][0]['message']['content'];
        case 401:
          throw Exception('Unauthorized: Invalid or missing API key');
        case 404:
          throw Exception(
              'API endpoint not found. Check model or URL: $decodedBody');
        case 429:
          throw Exception('Rate limit exceeded. Try again later');
        default:
          throw Exception(
              'Failed to get response: ${response.statusCode} - $decodedBody');
      }
    } catch (e) {
      print('[OpenRouterService] Error in analyzeImage: $e');
      rethrow;
    }
  }

  Future<String> getHealthAdvice(String question) async {
    if (apiKey.isEmpty) {
      throw Exception('API key is missing. Please configure .env file.');
    }

    final url = Uri.parse('$baseUrl/chat/completions');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json; charset=utf-8',
      'HTTP-Referer': 'https://smart-wearable-app.example.com',
      'X-Title': 'Smart Wearable App',
    };

    final body = jsonEncode({
      'model': 'meta-llama/llama-4-maverick:free',
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a health assistant providing general information. Do not diagnose or prescribe treatments. Always advise consulting a doctor for professional advice.'
        },
        {'role': 'user', 'content': question}
      ]
    });

    try {
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 60), onTimeout: () {
        throw Exception('Request timed out');
      });

      print('[OpenRouterService] Response status: ${response.statusCode}');
      final decodedBody = utf8.decode(response.bodyBytes);
      print('[OpenRouterService] Response body: $decodedBody');

      switch (response.statusCode) {
        case 200:
          final jsonData = jsonDecode(decodedBody);
          return jsonData['choices'][0]['message']['content'];
        case 401:
          throw Exception('Unauthorized: Invalid or missing API key');
        case 404:
          throw Exception(
              'API endpoint not found. Check model or URL: $decodedBody');
        case 429:
          throw Exception('Rate limit exceeded. Try again later');
        default:
          throw Exception(
              'Failed to get response: ${response.statusCode} - $decodedBody');
      }
    } catch (e) {
      print('[OpenRouterService] Error in getHealthAdvice: $e');
      rethrow;
    }
  }
}
