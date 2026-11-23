/// An optional public interest tag, shown only after its owner confirms it.
enum ProfileTag {
  dogLover('dog_lover', 'Dog Lover'),
  catLover('cat_lover', 'Cat Lover'),
  spotter('spotter', 'Spotter');

  const ProfileTag(this.value, this.label);
  final String value;
  final String label;

  static ProfileTag? fromValue(Object? value) {
    for (final tag in values) {
      if (tag.value == value) return tag;
    }
    return null;
  }
}

/// Counts of approved reports, not photos, scans or alternative AI guesses.
class ProfileTagActivity {
  const ProfileTagActivity({
    required this.approvedReports,
    required this.dogReports,
    required this.catReports,
  });

  static const minimumReports = 3;

  final int approvedReports;
  final int dogReports;
  final int catReports;

  factory ProfileTagActivity.fromJson(Map<String, dynamic> json) {
    int count(String key) {
      final value = json[key];
      if (value is! num || value < 0 || value % 1 != 0) {
        throw const FormatException('Invalid profile activity summary.');
      }
      return value.toInt();
    }

    final total = count('approved_reports');
    final dogs = count('dog_reports');
    final cats = count('cat_reports');
    if (dogs > total || cats > total) {
      throw const FormatException('Invalid profile activity summary.');
    }
    return ProfileTagActivity(
      approvedReports: total,
      dogReports: dogs,
      catReports: cats,
    );
  }

  /// A mixed dog/cat report can qualify both tags; the owner chooses one.
  List<ProfileTag> get suggestions {
    if (approvedReports < minimumReports) return const [];
    final tags = [
      if (dogReports * 5 >= approvedReports * 3) ProfileTag.dogLover,
      if (catReports * 5 >= approvedReports * 3) ProfileTag.catLover,
    ];
    return tags.isEmpty ? const [ProfileTag.spotter] : List.unmodifiable(tags);
  }
}
