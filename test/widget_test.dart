import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:in_class_15/main.dart';
import 'package:in_class_15/models/question.dart';
import 'package:in_class_15/services/trivia_service.dart';

Map<String, dynamic> _q(String text, String correct) => {
      'question': text,
      'correct_answer': correct,
      'incorrect_answers': ['Wrong A', 'Wrong B', 'Wrong C'],
    };

TriviaService _serviceReturning(int status, Object body) => TriviaService(
      client: MockClient((_) async => http.Response(jsonEncode(body), status)),
    );

void main() {
  test('decodes common HTML entities', () {
    expect(decodeHtmlEntities('&quot;Hi&quot; it&#039;s A &amp; B'),
        '"Hi" it\'s A & B');
    expect(decodeHtmlEntities('&amp;quot;'), '&quot;');
  });

  test('Question.fromJson combines and cleans options', () {
    final q = Question.fromJson(_q('Tom &amp; Jerry?', 'Yes &quot;1&quot;'));
    expect(q.questionText, 'Tom & Jerry?');
    expect(q.correctAnswer, 'Yes "1"');
    expect(q.options, hasLength(4));
    expect(q.options, contains('Yes "1"'));
  });

  test('non-zero response_code becomes an error', () async {
    final s = _serviceReturning(200, {'response_code': 1, 'results': []});
    expect(s.fetchQuestions(), throwsA(isA<TriviaException>()));
  });

  test('HTTP 500 becomes an error', () async {
    final s = _serviceReturning(500, {});
    expect(s.fetchQuestions(), throwsA(isA<TriviaException>()));
  });

  testWidgets('shows error state with retry on API failure', (tester) async {
    await tester.pumpWidget(TriviaShowdownApp(
      service: _serviceReturning(200, {'response_code': 5, 'results': []}),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('errorText')), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('full round: only the first answer counts, then results',
      (tester) async {
    final questions = List.generate(5, (i) => _q('Q$i?', 'Right$i'));
    await tester.pumpWidget(TriviaShowdownApp(
      service: _serviceReturning(200, {'response_code': 0, 'results': questions}),
    ));
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      expect(find.text('Question ${i + 1} of 5'), findsOneWidget);
      await tester.tap(find.text('Wrong A')); // first answer: wrong
      await tester.pump();
      await tester.tap(find.text('Right$i')); // second tap must not score
      await tester.pump();
      await tester.tap(find.text(i == 4 ? 'View Final Score' : 'Next Question →'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Final Score: 0 / 5'), findsOneWidget);
    await tester.tap(find.text('Simulate Score Sync'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('✓ Sync Simulation Complete'), findsOneWidget);
  });
}
