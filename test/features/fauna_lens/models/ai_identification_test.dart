import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:flutter_test/flutter_test.dart';

AiIdentification parse(String reply) => AiIdentification.fromModelReply(
  reply,
  provider: AiProvider.gemini,
  model: 'test-model',
  promptVersion: 'v-test',
);

void main() {
  group('AiIdentification.fromModelReply', () {
    test('reads a complete reply', () {
      final result = parse('''
{"animal_present": true,
 "possible_species": [
   {"common_name": "Red-eared Slider", "scientific_name": "Trachemys scripta elegans", "confidence": "medium"},
   {"common_name": "Malayan Box Turtle", "scientific_name": "Cuora amboinensis", "confidence": "low"}
 ],
 "visible_condition": "No injury seen.",
 "severity": "low",
 "severity_reason": "The animal looks calm.",
 "what_to_do": "Keep your distance."}''');

      expect(result.animalPresent, isTrue);
      expect(result.possibleSpecies, hasLength(2));
      expect(result.topGuess!.commonName, 'Red-eared Slider');
      expect(
        result.topGuess!.displayName,
        'Red-eared Slider (Trachemys scripta elegans)',
      );
      expect(result.topGuess!.confidence, SpeciesConfidence.medium);
      expect(result.possibleSpecies[1].confidence, SpeciesConfidence.low);
      expect(result.visibleCondition, 'No injury seen.');
      expect(result.severity, SeverityLevel.low);
      expect(result.severityReason, 'The animal looks calm.');
      expect(result.whatToDo, 'Keep your distance.');
      expect(result.provider, AiProvider.gemini);
      expect(result.model, 'test-model');
      expect(result.promptVersion, 'v-test');
      expect(result.possibleInvasive, isFalse);
    });

    test('accepts a reply wrapped in a Markdown code fence', () {
      final result = parse(
        'Here you go:\n```json\n{"animal_present": true, "possible_species": '
        '[{"common_name": "Gecko", "confidence": "HIGH"}]}\n```',
      );
      expect(result.topGuess!.commonName, 'Gecko');
      expect(result.topGuess!.scientificName, isEmpty);
      expect(result.topGuess!.displayName, 'Gecko');
      expect(result.topGuess!.confidence, SpeciesConfidence.high);
    });

    test('ignores reasoning in think tags before the answer', () {
      final result = parse(
        '<think>Is it {a turtle}? The shell says yes.</think> '
        '{"possible_species": [{"common_name": "Turtle"}]}',
      );
      expect(result.topGuess!.commonName, 'Turtle');
    });

    test('keeps at most three guesses and skips unnamed ones', () {
      final result = parse('''
{"possible_species": [
  {"common_name": " "}, {"common_name": "A"}, "not an object",
  {"common_name": "B"}, {"common_name": "C"}, {"common_name": "D"}
]}''');
      expect(result.possibleSpecies.map((s) => s.commonName), ['A', 'B', 'C']);
    });

    test('unknown labels become uncertain and missing text gets a default', () {
      final result = parse(
        '{"possible_species": [{"common_name": "A", "confidence": "87%"}], '
        '"severity": "extreme"}',
      );
      expect(result.topGuess!.confidence, SpeciesConfidence.uncertain);
      expect(result.severity, SeverityLevel.uncertain);
      expect(result.animalPresent, isNull);
      expect(result.visibleCondition, isNotEmpty);
      expect(result.severityReason, isNotEmpty);
      expect(result.whatToDo, contains('do not touch'));
    });

    test('drops guesses when the AI saw no animal', () {
      final result = parse(
        '{"animal_present": false, "possible_species": [{"common_name": "A"}]}',
      );
      expect(result.animalPresent, isFalse);
      expect(result.hasSpecies, isFalse);
      expect(result.topGuess, isNull);
    });

    test('keeps a short, single-line photo subject', () {
      expect(
        parse(
          '{"animal_present": false, "photo_subject": " a red\\n mug. "}',
        ).photoSubject,
        'a red mug',
      );
      expect(parse('{}').photoSubject, isEmpty);
      final long = parse('{"photo_subject": "${'x' * 200}"}').photoSubject;
      expect(long.length, AiIdentification.maxSubjectLength + 1);
      expect(long, endsWith('…'));
    });

    test('throws FormatException when there is no JSON object', () {
      expect(() => parse('I cannot help with that.'), throwsFormatException);
      expect(() => parse('{not json}'), throwsFormatException);
      expect(() => parse('[1, 2]'), throwsFormatException);
    });
  });

  test('withInvasiveMatch sets the hint and keeps everything else', () {
    final result = parse(
      '{"possible_species": [{"common_name": "A"}], "what_to_do": "Wait."}',
    ).withInvasiveMatch('Red-eared Slider');
    expect(result.possibleInvasive, isTrue);
    expect(result.invasiveMatch, 'Red-eared Slider');
    expect(result.topGuess!.commonName, 'A');
    expect(result.whatToDo, 'Wait.');
  });
}
