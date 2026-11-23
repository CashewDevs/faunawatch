import 'dart:convert';

import 'package:faunawatch/features/app_update/models/app_release.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Thrown when the newest release could not be checked.
final class AppReleaseException implements Exception {
  const AppReleaseException(this.message);

  final String message;

  @override
  String toString() => 'AppReleaseException: $message';
}

/// Finds the newest published FaunaWatch release.
abstract interface class AppReleaseService {
  /// The newest release, or null when none has been published yet.
  ///
  /// Throws [AppReleaseException] when the check fails.
  Future<AppRelease?> fetchLatest();
}

/// Reads the newest release of the public `CashewDevs/faunawatch` repository
/// from GitHub's REST API. No sign-in is needed because the repository is
/// public. Drafts and releases marked "pre-release" are skipped by GitHub.
final class GitHubAppReleaseService implements AppReleaseService {
  GitHubAppReleaseService(this._client);

  static final latestReleaseUrl = Uri.parse(
    'https://api.github.com/repos/CashewDevs/faunawatch/releases/latest',
  );

  static const _timeout = Duration(seconds: 15);

  final http.Client _client;

  @override
  Future<AppRelease?> fetchLatest() async {
    final http.Response response;
    try {
      response = await _client
          .get(
            latestReleaseUrl,
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(_timeout);
    } catch (_) {
      throw const AppReleaseException('Could not reach GitHub.');
    }

    // GitHub answers 404 when the repository has no published release yet.
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw AppReleaseException('GitHub answered ${response.statusCode}.');
    }

    try {
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Release is not an object.');
      }
      return AppRelease.fromGitHubJson(json);
    } on FormatException catch (error) {
      throw AppReleaseException('Unreadable release: ${error.message}');
    }
  }
}

final appReleaseServiceProvider = Provider<AppReleaseService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return GitHubAppReleaseService(client);
});
