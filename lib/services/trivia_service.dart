import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/question.dart';

/// A user-readable error raised while loading trivia.
class TriviaException implements Exception {
  final String message;
  const TriviaException(this.message);
  @override
  String toString() => message;
}

/// Keeps network + JSON interpretation out of the widget layer.
class TriviaService {
  static final Uri endpoint = Uri.parse(
    'https://opentdb.com/api.php?amount=5&category=9&difficulty=easy&type=multiple',
  );

  final http.Client _client;
  final Duration timeout;

  TriviaService({http.Client? client, this.timeout = const Duration(seconds: 10)})
      : _client = client ?? http.Client();

  Future<List<Question>> fetchQuestions() async {
    final http.Response response;
    try {
      response = await _client.get(endpoint).timeout(timeout);
    } on TimeoutException {
      throw const TriviaException('The request timed out. Check your connection and try again.');
    } on http.ClientException {
      // Includes socket failures (no internet / DNS) on mobile and web.
      throw const TriviaException('Could not reach the trivia server. Check your connection and try again.');
    } catch (_) {
      throw const TriviaException('Unexpected network error. Please try again.');
    }

    // 1. Transport-level check.
    if (response.statusCode != 200) {
      throw TriviaException(
        response.statusCode == 429
            ? 'Too many requests (HTTP 429). Wait 5 seconds and retry.'
            : 'Server error: HTTP ${response.statusCode}.',
      );
    }

    // 2. Parse the body.
    final Map<String, dynamic> data;
    try {
      data = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const TriviaException('The server returned unreadable data.');
    }

    // 3. API-level check (HTTP 200 does not guarantee usable questions).
    final code = data['response_code'];
    if (code != 0) {
      throw TriviaException(_describeApiCode(code));
    }
    final results = data['results'];
    if (results is! List || results.isEmpty) {
      throw const TriviaException('No questions were returned.');
    }

    // 4. Map JSON records into Question models.
    try {
      return results
          .map((r) => Question.fromJson(r as Map<String, dynamic>))
          .toList();
    } on FormatException catch (e) {
      throw TriviaException('Bad question data: ${e.message}');
    }
  }

  static String _describeApiCode(Object? code) {
    switch (code) {
      case 1:
        return 'API code 1: not enough questions for this query.';
      case 2:
        return 'API code 2: invalid request parameter.';
      case 3:
      case 4:
        return 'API code $code: session token problem.';
      case 5:
        return 'API code 5: rate limited. Wait 5 seconds and retry.';
      default:
        return 'Trivia API did not return questions (code $code).';
    }
  }
}
