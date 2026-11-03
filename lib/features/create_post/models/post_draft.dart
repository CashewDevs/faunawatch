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
  });

  final ReportCategory category;
  final double latitude, longitude;
  final String description, species, notes;
  final String? photoPath;

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
      'ai_status': 'unavailable',
    };
  }
}
