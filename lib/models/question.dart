import 'dart:math';

/// Decodes the HTML entities the Open Trivia Database commonly returns.
String decodeHtmlEntities(String input) {
  const named = {
    '&quot;': '"',
    '&#039;': "'",
    '&apos;': "'",
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&rsquo;': '’',
    '&lsquo;': '‘',
    '&rdquo;': '”',
    '&ldquo;': '“',
    '&hellip;': '…',
    '&eacute;': 'é',
    '&ntilde;': 'ñ',
    '&ouml;': 'ö',
    '&uuml;': 'ü',
    '&shy;': '',
    '&nbsp;': ' ',
  };
  var out = input;
  // Numeric entities like &#8217; or &#x2019;
  out = out.replaceAllMapped(RegExp(r'&#(x?)([0-9a-fA-F]+);'), (m) {
    final code = int.tryParse(m[2]!, radix: m[1]!.isEmpty ? 10 : 16);
    return code == null ? m[0]! : String.fromCharCode(code);
  });
  // Decode &amp; last so "&amp;quot;" isn't double-decoded.
  named.forEach((entity, value) {
    if (entity != '&amp;') out = out.replaceAll(entity, value);
  });
  return out.replaceAll('&amp;', '&');
}

class Question {
  final String questionText;
  final String correctAnswer;
  final List<String> options;

  Question({
    required this.questionText,
    required this.correctAnswer,
    required this.options,
  });

  factory Question.fromJson(Map<String, dynamic> json, {Random? random}) {
    final question = json['question'];
    final correct = json['correct_answer'];
    final incorrect = json['incorrect_answers'];
    if (question is! String || correct is! String || incorrect is! List) {
      throw const FormatException('Question record is missing fields.');
    }
    final correctAnswer = decodeHtmlEntities(correct);
    final options = [
      correctAnswer,
      ...incorrect.map((e) => decodeHtmlEntities(e.toString())),
    ]..shuffle(random);
    return Question(
      questionText: decodeHtmlEntities(question),
      correctAnswer: correctAnswer,
      options: options,
    );
  }
}
