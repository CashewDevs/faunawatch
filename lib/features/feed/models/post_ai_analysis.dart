import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';

/// One of the AI's species guesses for a post.
class PostAiSpecies {
  const PostAiSpecies({
    required this.commonName,
    this.scientificName,
    this.confidence = SpeciesConfidence.uncertain,
  });

  final String commonName;
  final String? scientificName;
  final SpeciesConfidence confidence;
}

/// The parts of a post's completed AI analysis that anyone who can see the
/// post may read.
///
/// `responder_briefing` and the report's `user_notes` are never part of it:
/// they stay with admins and responders.
class PostAiAnalysis {
  const PostAiAnalysis({
    this.species = const [],
    this.visualCondition,
    this.severity,
    this.possibleInvasive = false,
    this.invasiveMatchName,
    this.incidentSummary,
    this.safetyRecommendations,
    this.communityWarning,
  });

  final List<PostAiSpecies> species;
  final String? visualCondition;
  final SeverityLevel? severity;
  final bool possibleInvasive;

  /// The invasive species the guess matched in `species_reference`, if any.
  final String? invasiveMatchName;
  final String? incidentSummary, safetyRecommendations, communityWarning;

  /// Builds the analysis from a feed or own-report row, or returns null when
  /// the row has no AI result at all.
  static PostAiAnalysis? fromRow(Map<String, dynamic> row) {
    final severityText = _clean(row['severity']);
    final analysis = PostAiAnalysis(
      species: _species(row['possible_species']),
      visualCondition: _clean(row['visual_condition_assessment']),
      severity: severityText == null ? null : SeverityLevel.parse(severityText),
      possibleInvasive: row['possible_invasive'] == true,
      invasiveMatchName: _clean(row['invasive_match_name']),
      incidentSummary: _clean(row['incident_summary']),
      safetyRecommendations: _clean(row['safety_recommendations']),
      communityWarning: _clean(row['community_warning']),
    );
    return analysis._isEmpty ? null : analysis;
  }

  bool get _isEmpty =>
      species.isEmpty &&
      visualCondition == null &&
      severity == null &&
      !possibleInvasive &&
      incidentSummary == null &&
      safetyRecommendations == null &&
      communityWarning == null;

  static String? _clean(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// Rows are written with `common_name`; the older documented shape used
  /// `name`. Guesses without a name are skipped.
  static List<PostAiSpecies> _species(Object? value) {
    if (value is! List) return const [];
    return [
      for (final entry in value)
        if (entry is Map &&
            (_clean(entry['common_name']) ?? _clean(entry['name'])) != null)
          PostAiSpecies(
            commonName:
                (_clean(entry['common_name']) ?? _clean(entry['name']))!,
            scientificName: _clean(entry['scientific_name']),
            confidence: SpeciesConfidence.parse(entry['confidence']),
          ),
    ];
  }
}
