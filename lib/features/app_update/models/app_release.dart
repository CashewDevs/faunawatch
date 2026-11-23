import 'package:faunawatch/features/app_update/models/app_version.dart';

/// A published FaunaWatch release on GitHub.
final class AppRelease {
  const AppRelease({
    required this.version,
    required this.pageUrl,
    this.notes,
    this.apkUrl,
  });

  /// The file name every release's Android app must be uploaded as, so the
  /// app (and the "latest" download link) can find it.
  static const apkFileName = 'faunawatch.apk';

  /// Read from the release tag, e.g. `v1.0.0+2`.
  final AppVersion version;

  /// The release page on GitHub.
  final Uri pageUrl;

  /// The release description, or null when it is empty.
  final String? notes;

  /// Direct download of [apkFileName], or null when the release has no such
  /// file attached.
  final Uri? apkUrl;

  /// Reads one release from GitHub's REST API (`GET /releases/latest`).
  ///
  /// Throws a [FormatException] when the tag is not a version or a required
  /// field is missing.
  factory AppRelease.fromGitHubJson(Map<String, dynamic> json) {
    final tag = json['tag_name'];
    final page = json['html_url'];
    if (tag is! String || page is! String) {
      throw const FormatException('Release is missing its tag or page.');
    }
    final version = AppVersion.tryParse(tag);
    if (version == null) {
      throw FormatException('Release tag is not a version: $tag');
    }

    Uri? apkUrl;
    final assets = json['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is Map &&
            asset['name'] == apkFileName &&
            asset['browser_download_url'] is String) {
          apkUrl = Uri.tryParse(asset['browser_download_url'] as String);
          break;
        }
      }
    }

    final body = json['body'];
    final notes = body is String && body.trim().isNotEmpty ? body.trim() : null;

    return AppRelease(
      version: version,
      pageUrl: Uri.parse(page),
      notes: notes,
      apkUrl: apkUrl,
    );
  }
}
