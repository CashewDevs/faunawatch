import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';

enum ReportCategory {
  animalInNeed('animal_in_need', 'Animal in need'),
  potentiallyDangerousAnimal(
    'potentially_dangerous_animal',
    'Potentially dangerous animal',
  ),
  possibleInvasiveSpecies(
    'possible_invasive_species',
    'Possible invasive species',
  ),
  otherWildlifeIncident('other_wildlife_incident', 'Other wildlife incident');

  const ReportCategory(this.value, this.label);
  final String value;
  final String label;
}

/// User-entered report data. Coordinates are mandatory at the persistence boundary.
class PostDraft {
  const PostDraft({
    required this.category,
    required this.latitude,
    required this.longitude,
    this.description = '',
    this.species = '',
    this.notes = '',
    this.photoPath,
    this.aiResult,
  });

  final ReportCategory category;
  final double latitude, longitude;
  final String description, species, notes;
  final String? photoPath;

  /// The FaunaLens analysis of [photoPath], saved to `ai_analyses` with the
  /// report. Only kept with the photo it describes.
  final AiIdentification? aiResult;

  /// The analysis to save, if any. Ignored without its photo.
  AiIdentification? get analysis => photoPath == null ? null : aiResult;

  static bool validCoordinates(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  Map<String, dynamic> toRow(String userId) {
    if (!validCoordinates(latitude, longitude)) {
      throw ArgumentError('A valid report location is required.');
    }
    String? optional(String value) =>
        value.trim().isEmpty ? null : value.trim();
    return {
      'user_id': userId,
      'category': category.value,
      'latitude': latitude,
      'longitude': longitude,
      'description': optional(description),
      'user_species': optional(species),
      'user_notes': optional(notes),
      'status': 'pending',
      // The analysis row is inserted in the same submission; if that fails
      // the report is removed, so 'completed' never lacks its row.
      'ai_status': analysis == null ? 'unavailable' : 'completed',
    };
  }
}
