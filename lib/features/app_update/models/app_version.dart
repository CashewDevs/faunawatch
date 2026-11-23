/// An app version as written in `pubspec.yaml` and in GitHub release tags:
/// `1.0.0+2` or `v1.0.0+2` (name `1.0.0`, build number `2`).
///
/// The build number is the one Android uses to decide whether an install is
/// an update, so it is compared too when both versions have one.
final class AppVersion {
  const AppVersion(this.major, this.minor, this.patch, {this.build});

  final int major;
  final int minor;
  final int patch;

  /// The number after `+`, or null when the text had none.
  final int? build;

  static final _pattern = RegExp(
    r'^[vV]?(\d+)\.(\d+)\.(\d+)(?:-[0-9A-Za-z.-]+)?(?:\+(\d+))?$',
  );

  /// Reads `1.0.0`, `1.0.0+2`, `v1.0.0+2` (and ignores a `-beta`-style
  /// suffix). Returns null for anything else.
  static AppVersion? tryParse(String text) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) return null;
    final build = match.group(4);
    return AppVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      build: build == null ? null : int.parse(build),
    );
  }

  /// The version name without the build number, e.g. `1.0.0`.
  String get name => '$major.$minor.$patch';

  /// How the version is shown to people, e.g. `1.0.0 (2)`.
  String get label => build == null ? name : '$name ($build)';

  /// Whether this version is newer than [other].
  ///
  /// The name is compared first; when the names are equal, the build numbers
  /// decide, but only if both versions have one.
  bool isNewerThan(AppVersion other) {
    final parts = [
      major - other.major,
      minor - other.minor,
      patch - other.patch,
    ];
    for (final difference in parts) {
      if (difference != 0) return difference > 0;
    }
    final mine = build;
    final theirs = other.build;
    return mine != null && theirs != null && mine > theirs;
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch &&
      other.build == build;

  @override
  int get hashCode => Object.hash(major, minor, patch, build);

  @override
  String toString() => build == null ? name : '$name+$build';
}
