import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ScamDetectionService {
  // For Chrome/Web:
  static const String baseUrl = 'http://localhost:8000';
  
  // For Android emulator (commented out):
  // static const String baseUrl = 'http://10.0.2.2:8000';

  Future<Map<String, dynamic>> analyzeText(String text) async {
    try {
      print('Sending request to: $baseUrl/analyze');
      print('Text: ${text.substring(0, min(50, text.length))}...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/analyze'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'text': text}),
      ).timeout(const Duration(seconds: 15));

      print('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Analysis received successfully');
        return data;
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Connection error: $e');
      throw Exception('Cannot connect to server at $baseUrl. Make sure Python server is running.');
    }
  }

  Future<bool> checkHealth() async {
    try {
      print('Checking server health at: $baseUrl/health');
      
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 3));
      
      final isHealthy = response.statusCode == 200;
      print(isHealthy ? 'Server is healthy' : 'Server returned ${response.statusCode}');
      
      return isHealthy;
    } catch (e) {
      print('Health check failed: $e');
      return false;
    }
  }
}