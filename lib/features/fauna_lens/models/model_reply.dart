import 'dart:convert';

/// Reads the JSON object an AI was asked to reply with.
///
/// Tolerates Markdown code fences, text around the object and `<think>`
/// sections from reasoning models. Throws [FormatException] when the reply
/// holds no JSON object.
Map<String, dynamic> decodeModelReplyObject(String reply) {
  final answer = reply.replaceAll(
    RegExp(r'<think>.*?</think>', dotAll: true),
    '',
  );
  final start = answer.indexOf('{');
  final end = answer.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const FormatException('The AI reply has no JSON object.');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(answer.substring(start, end + 1));
  } on FormatException {
    throw const FormatException('The AI reply is not valid JSON.');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('The AI reply is not a JSON object.');
  }
  return decoded;
}
