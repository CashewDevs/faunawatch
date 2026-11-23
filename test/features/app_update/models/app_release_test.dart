import 'package:faunawatch/features/app_update/models/app_release.dart';
import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> releaseJson({
  Object? tag = 'v1.0.1+3',
  Object? body = '  New splash screen.  ',
  List<Object?> assets = const [],
}) => {
  'tag_name': tag,
  'html_url': 'https://github.com/CashewDevs/faunawatch/releases/tag/v1.0.1+3',
  'body': body,
  'assets': assets,
};

void main() {
  group('AppRelease.fromGitHubJson', () {
    test('reads the version, page and trimmed notes', () {
      final release = AppRelease.fromGitHubJson(releaseJson());

      expect(release.version, const AppVersion(1, 0, 1, build: 3));
      expect(
        release.pageUrl.toString(),
        'https://github.com/CashewDevs/faunawatch/releases/tag/v1.0.1+3',
      );
      expect(release.notes, 'New splash screen.');
      expect(release.apkUrl, isNull);
    });

    test('finds the faunawatch.apk download among the assets', () {
      final release = AppRelease.fromGitHubJson(
        releaseJson(
          assets: [
            {
              'name': 'notes.txt',
              'browser_download_url': 'https://example.com/notes.txt',
            },
            {
              'name': AppRelease.apkFileName,
              'browser_download_url': 'https://example.com/faunawatch.apk',
            },
          ],
        ),
      );

      expect(release.apkUrl.toString(), 'https://example.com/faunawatch.apk');
    });

    test('treats empty or missing notes as none', () {
      expect(AppRelease.fromGitHubJson(releaseJson(body: '   ')).notes, isNull);
      expect(AppRelease.fromGitHubJson(releaseJson(body: null)).notes, isNull);
    });

    test('throws a FormatException for a tag that is not a version', () {
      expect(
        () => AppRelease.fromGitHubJson(releaseJson(tag: 'first-try')),
        throwsFormatException,
      );
      expect(
        () => AppRelease.fromGitHubJson(releaseJson(tag: null)),
        throwsFormatException,
      );
    });
  });

  group('AppRelease.notesHeadline', () {
    AppRelease withNotes(String? body) =>
        AppRelease.fromGitHubJson(releaseJson(body: body));

    test('is the first line without a list marker', () {
      expect(
        withNotes('- Faster map\n- New banner').notesHeadline,
        'Faster map',
      );
      expect(withNotes('* Faster map').notesHeadline, 'Faster map');
      expect(withNotes('• Faster map').notesHeadline, 'Faster map');
      expect(withNotes('Faster map.').notesHeadline, 'Faster map.');
    });

    test('skips empty lines and bare markers', () {
      expect(withNotes('-\n\n  - Faster map').notesHeadline, 'Faster map');
    });

    test('is null without notes', () {
      expect(withNotes(null).notesHeadline, isNull);
      expect(withNotes('-').notesHeadline, isNull);
    });
  });
}
