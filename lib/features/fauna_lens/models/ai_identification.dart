import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/fauna_lens/models/animal_box.dart';
import 'package:faunawatch/features/fauna_lens/models/model_reply.dart';
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

/// One guess at what an animal in the photo is.
class PossibleSpecies {
  const PossibleSpecies({
    required this.commonName,
    this.scientificName = '',
    this.confidence = SpeciesConfidence.uncertain,
    this.boxColor,
  });

  final String commonName;
  final String scientificName;
  final SpeciesConfidence confidence;

  /// When several animals were chosen: the colour of the box this guess is
  /// about, if the AI said. Only shown on screen, never saved.
  final AnimalBoxColor? boxColor;

  /// "Common name (Scientific name)", or just the common name.
  String get displayName =>
      scientificName.isEmpty ? commonName : '$commonName ($scientificName)';
}

/// The curated `species_reference` entry an AI guess matched.
class SpeciesReferenceMatch {
  const SpeciesReferenceMatch({required this.id, required this.commonName});

  /// `species_reference.id`, saved as `ai_analyses.invasive_match_species_id`.
  final String id;
  final String commonName;
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
    this.aiCategory = ReportCategory.otherWildlifeIncident,
    this.animalCount = 1,
    this.backupKeyUse,
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

  /// The invasive reference entry the top guess matched, if any.
  final SpeciesReferenceMatch? invasiveMatch;

  /// The category the AI chose. Never [ReportCategory.possibleInvasiveSpecies]:
  /// the AI is not offered it.
  final ReportCategory aiCategory;

  /// How many boxed animals the analysis covers. With one, [possibleSpecies]
  /// holds up to three guesses for it; with more, one best guess per animal.
  final int animalCount;

  /// Set when the main key failed and the backup key produced this result
  /// ([provider] and [model] are then the backup's). Shown as a note on the
  /// result; not saved.
  final BackupKeyUse? backupKeyUse;

  bool get usedBackupKey => backupKeyUse != null;

  bool get coversSeveralAnimals => animalCount > 1;

  /// The guesses checked against the curated invasive list: the top guess for
  /// one animal, or every animal's guess when there are several.
  List<PossibleSpecies> get guessesToCheck =>
      coversSeveralAnimals ? possibleSpecies : [?topGuess];

  /// What goes in the post's species field: the top guess, or each animal's
  /// guess joined with commas. Null when the AI named no species.
  String? get speciesSummary {
    if (!hasSpecies) return null;
    if (!coversSeveralAnimals) return topGuess!.displayName;
    return possibleSpecies.map((species) => species.displayName).join(', ');
  }

  /// The report category for this result: "possible invasive species" when
  /// the top guess matched the curated reference list, otherwise the AI's
  /// choice.
  ReportCategory get category =>
      possibleInvasive ? ReportCategory.possibleInvasiveSpecies : aiCategory;

  /// The categories the AI may choose from, by their `reports.category` value.
  static const aiCategories = [
    ReportCategory.animalInNeed,
    ReportCategory.potentiallyDangerousAnimal,
    ReportCategory.otherWildlifeIncident,
  ];

  /// Reads a category from the AI reply. Anything unknown, including the
  /// invasive category the AI is not offered, counts as other.
  static ReportCategory parseCategory(Object? raw) {
    final text = raw?.toString().trim().toLowerCase();
    return aiCategories.firstWhere(
      (category) => category.value == text,
      orElse: () => ReportCategory.otherWildlifeIncident,
    );
  }

  bool get possibleInvasive => invasiveMatch != null;

  bool get hasSpecies => possibleSpecies.isNotEmpty;

  PossibleSpecies? get topGuess => hasSpecies ? possibleSpecies.first : null;

  /// The `ai_analyses` row for this result, attached to [reportId].
  ///
  /// Only existing columns are written. [severityReason] and [photoSubject]
  /// have no column and are not saved. Columns the prompt doesn't ask for
  /// (validation, summaries, species_origin) are left null.
  /// `input_fingerprint` is also left null: its unique cache index spans
  /// every report, so the same photo posted twice with the same model would
  /// be rejected, and the AI saw a resized copy rather than the uploaded file.
  Map<String, dynamic> toAnalysisRow(String reportId) {
    String? optional(String value) => value.isEmpty ? null : value;
    return {
      'report_id': reportId,
      'status': 'completed',
      'animal_present': animalPresent,
      // Shape agreed in 20261027000700_harden_ai_analyses.sql; at most 3.
      'possible_species': [
        for (final species in possibleSpecies.take(maxSpecies))
          {
            'common_name': species.commonName,
            'scientific_name': optional(species.scientificName),
            'confidence': species.confidence.value,
          },
      ],
      'visual_condition_assessment': visibleCondition,
      'severity': severity.value,
      'safety_recommendations': whatToDo,
      'possible_invasive': possibleInvasive,
      'invasive_match_species_id': invasiveMatch?.id,
      'provider': provider.name,
      'model': model,
      'prompt_version': promptVersion,
      'is_preliminary': true,
    };
  }

  AiIdentification withInvasiveMatch(SpeciesReferenceMatch? match) =>
      _copy(invasiveMatch: match, backupKeyUse: backupKeyUse);

  /// The same result, marked as produced by the backup key because of [use].
  AiIdentification withBackupKeyUse(BackupKeyUse use) =>
      _copy(invasiveMatch: invasiveMatch, backupKeyUse: use);

  AiIdentification _copy({
    required SpeciesReferenceMatch? invasiveMatch,
    required BackupKeyUse? backupKeyUse,
  }) => AiIdentification(
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
    invasiveMatch: invasiveMatch,
    aiCategory: aiCategory,
    animalCount: animalCount,
    backupKeyUse: backupKeyUse,
  );

  /// Parses the JSON object the AI was asked to reply with, about the
  /// animals in [boxes].
  ///
  /// Tolerates Markdown code fences and text around the object, missing
  /// fields and unknown labels. Throws [FormatException] when the reply holds
  /// no JSON object at all.
  static AiIdentification fromModelReply(
    String reply, {
    required AiProvider provider,
    required String model,
    required String promptVersion,
    List<AnimalBox> boxes = const [],
  }) {
    final json = decodeModelReplyObject(reply);
    final animalCount = boxes.isEmpty ? 1 : boxes.length;
    // One animal gets up to three guesses; several get one guess each.
    final maxGuesses = animalCount == 1 ? maxSpecies : animalCount;
    final chosenColors = {for (final box in boxes) box.color};

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
        final boxColor = AnimalBoxColor.parse(entry['box']);
        species.add(
          PossibleSpecies(
            commonName: common.trim(),
            scientificName: scientific is String ? scientific.trim() : '',
            confidence: SpeciesConfidence.parse(entry['confidence']),
            boxColor: animalCount > 1 && chosenColors.contains(boxColor)
                ? boxColor
                : null,
          ),
        );
        if (species.length == maxGuesses) break;
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
      aiCategory: parseCategory(json['category']),
      animalCount: animalCount,
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

/// Why the backup key was used instead of the main key.
class BackupKeyUse {
  const BackupKeyUse({required this.mainFailure, required this.mainProvider});

  /// What went wrong with the main key: [IdentificationFailure.invalidKey],
  /// [IdentificationFailure.rateLimited] or
  /// [IdentificationFailure.unavailable].
  final IdentificationFailure mainFailure;

  /// The provider of the main key that failed.
  final AiProvider mainProvider;

  @override
  bool operator ==(Object other) =>
      other is BackupKeyUse &&
      other.mainFailure == mainFailure &&
      other.mainProvider == mainProvider;

  @override
  int get hashCode => Object.hash(mainFailure, mainProvider);
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
