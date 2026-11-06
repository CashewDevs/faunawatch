import 'dart:convert';

import 'package:faunawatch/features/settings/models/ai_provider.dart';

/// How sure the AI is about one possible species. Qualitative only: the app
/// never shows a percentage (matches the `confidence_label` database enum).
enum SpeciesConfidence {
  high('high', 'High'),
  medium('medium', 'Medium'),
  low('low', 'Low'),
  uncertain('uncertain', 'Uncertain');

  const SpeciesConfidence(this.value, this.label);

  final String value;
  final String label;

  /// Reads a label from the AI reply. Anything unknown counts as uncertain.
  static SpeciesConfidence parse(Object? raw) {
    final text = raw?.toString().trim().toLowerCase();
    return values.firstWhere(
      (confidence) => confidence.value == text,
      orElse: () => uncertain,
    );
  }
}

/// How urgently the animal or people nearby may need help (matches the
/// `severity_level` database enum).
enum SeverityLevel {
  low('low', 'Low'),
  moderate('moderate', 'Moderate'),
  high('high', 'High'),
  critical('critical', 'Critical'),
  uncertain('uncertain', 'Uncertain');

  const SeverityLevel(this.value, this.label);

  final String value;
  final String label;

  /// Reads a level from the AI reply. Anything unknown counts as uncertain.
  static SeverityLevel parse(Object? raw) {
    final text = raw?.toString().trim().toLowerCase();
    return values.firstWhere(
      (level) => level.value == text,
      orElse: () => uncertain,
    );
  }
}

/// One guess at what the animal in the photo is.
class PossibleSpecies {
  const PossibleSpecies({
    required this.commonName,
    this.scientificName = '',
    this.confidence = SpeciesConfidence.uncertain,
  });

  final String commonName;
  final String scientificName;
  final SpeciesConfidence confidence;

  /// "Common name (Scientific name)", or just the common name.
  String get displayName =>
      scientificName.isEmpty ? commonName : '$commonName ($scientificName)';
}

/// A preliminary AI assessment of a FaunaLens photo.
///
/// Every field is a suggestion. The invasive hint is never decided by the AI:
/// it is set only when the top guess matches the curated species reference.
class AiIdentification {
  const AiIdentification({
    required this.animalPresent,
    required this.possibleSpecies,
    required this.visibleCondition,
    required this.severity,
    required this.severityReason,
    required this.whatToDo,
    required this.provider,
    required this.model,
    required this.promptVersion,
    this.photoSubject = '',
    this.invasiveMatch,
  });

  /// The most guesses the app shows (and the database accepts).
  static const maxSpecies = 3;

  /// The longest photo description kept from the AI reply.
  static const maxSubjectLength = 80;

  static const _defaultCondition =
      "The photo doesn't show enough to judge the animal's condition.";
  static const _defaultSeverityReason = 'Based on the photo only.';
  static const _defaultWhatToDo =
      'Keep a safe distance and do not touch, feed or handle the animal.';

  /// False when the AI saw no animal; null when it could not tell.
  final bool? animalPresent;
  final List<PossibleSpecies> possibleSpecies;
  final String visibleCondition;
  final SeverityLevel severity;
  final String severityReason;
  final String whatToDo;
  final AiProvider provider;
  final String model;
  final String promptVersion;

  /// A few words on what the photo shows (e.g. "a coffee mug"). Only asked
  /// for so a photo without an animal can be explained; may be empty.
  final String photoSubject;

  /// Name of the reference entry the top guess matched, if any.
  final String? invasiveMatch;

  bool get possibleInvasive => invasiveMatch != null;

  bool get hasSpecies => possibleSpecies.isNotEmpty;

  PossibleSpecies? get topGuess => hasSpecies ? possibleSpecies.first : null;

  AiIdentification withInvasiveMatch(String? match) => AiIdentification(
    animalPresent: animalPresent,
    possibleSpecies: possibleSpecies,
    visibleCondition: visibleCondition,
    severity: severity,
    severityReason: severityReason,
    whatToDo: whatToDo,
    provider: provider,
    model: model,
    promptVersion: promptVersion,
    photoSubject: photoSubject,
    invasiveMatch: match,
  );

  /// Parses the JSON object the AI was asked to reply with.
  ///
  /// Tolerates Markdown code fences and text around the object, missing
  /// fields and unknown labels. Throws [FormatException] when the reply holds
  /// no JSON object at all.
  static AiIdentification fromModelReply(
    String reply, {
    required AiProvider provider,
    required String model,
    required String promptVersion,
  }) {
    // Reasoning models may think aloud in <think> tags before answering.
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
    final Map<String, dynamic> json = decoded;

    String text(String key, String fallback) {
      final value = json[key];
      final trimmed = value is String ? value.trim() : '';
      return trimmed.isEmpty ? fallback : trimmed;
    }

    final present = json['animal_present'];
    final animalPresent = present is bool ? present : null;
    final species = <PossibleSpecies>[];
    final rawSpecies = json['possible_species'];
    if (animalPresent != false && rawSpecies is List) {
      for (final entry in rawSpecies) {
        if (entry is! Map) continue;
        final common = entry['common_name'];
        if (common is! String || common.trim().isEmpty) continue;
        final scientific = entry['scientific_name'];
        species.add(
          PossibleSpecies(
            commonName: common.trim(),
            scientificName: scientific is String ? scientific.trim() : '',
            confidence: SpeciesConfidence.parse(entry['confidence']),
          ),
        );
        if (species.length == maxSpecies) break;
      }
    }

    return AiIdentification(
      animalPresent: animalPresent,
      possibleSpecies: species,
      visibleCondition: text('visible_condition', _defaultCondition),
      severity: SeverityLevel.parse(json['severity']),
      severityReason: text('severity_reason', _defaultSeverityReason),
      whatToDo: text('what_to_do', _defaultWhatToDo),
      provider: provider,
      model: model,
      promptVersion: promptVersion,
      photoSubject: _subject(json['photo_subject']),
    );
  }

  /// One line of at most [maxSubjectLength] characters, without a trailing
  /// full stop, so it reads well inside a sentence.
  static String _subject(Object? raw) {
    if (raw is! String) return '';
    var subject = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (subject.length > maxSubjectLength) {
      subject = '${subject.substring(0, maxSubjectLength).trimRight()}…';
    }
    return subject.replaceAll(RegExp(r'[.!]+$'), '');
  }
}

/// Why an identification could not be completed.
enum IdentificationFailure {
  signedOut,
  noKey,
  invalidKey,
  rateLimited,
  unavailable,
  network,
  unreadablePhoto,
  badResponse,

  /// The AI saw no animal in the photo; FaunaLens only handles animals.
  notAnimal,
}

/// Thrown by the identification service. Never carries the key or the raw
/// provider response.
class IdentificationException implements Exception {
  const IdentificationException(
    this.failure, {
    this.provider,
    this.photoSubject = '',
  });

  final IdentificationFailure failure;

  /// The provider that was used, when one was.
  final AiProvider? provider;

  /// For [IdentificationFailure.notAnimal]: what the AI saw instead, already
  /// shortened by [AiIdentification.fromModelReply]. May be empty.
  final String photoSubject;

  @override
  String toString() => 'IdentificationException(${failure.name})';
}
