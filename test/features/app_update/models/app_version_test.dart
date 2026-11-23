import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppVersion.tryParse', () {
    test('reads name and build number, with or without a leading v', () {
      expect(
        AppVersion.tryParse('1.0.0+2'),
        const AppVersion(1, 0, 0, build: 2),
      );
      expect(
        AppVersion.tryParse('v1.2.3+45'),
        const AppVersion(1, 2, 3, build: 45),
      );
      expect(AppVersion.tryParse(' V2.0.0 '), const AppVersion(2, 0, 0));
    });

    test('ignores a pre-release suffix', () {
      expect(
        AppVersion.tryParse('1.0.0-beta.1+7'),
        const AppVersion(1, 0, 0, build: 7),
      );
    });

    test('returns null for anything that is not a version', () {
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('latest'), isNull);
      expect(AppVersion.tryParse('1.0'), isNull);
      expect(AppVersion.tryParse('1.0.0+'), isNull);
      expect(AppVersion.tryParse('release-1.0.0'), isNull);
    });
  });

  group('AppVersion.label', () {
    test('shows the build number in brackets', () {
      expect(const AppVersion(1, 0, 0, build: 2).label, '1.0.0 (2)');
      expect(const AppVersion(1, 0, 0).label, '1.0.0');
    });
  });

  group('AppVersion.isNewerThan', () {
    const installed = AppVersion(1, 2, 3, build: 10);

    test('a higher major, minor or patch is newer, whatever the build', () {
      expect(
        const AppVersion(2, 0, 0, build: 1).isNewerThan(installed),
        isTrue,
      );
      expect(const AppVersion(1, 3, 0).isNewerThan(installed), isTrue);
      expect(
        const AppVersion(1, 2, 4, build: 1).isNewerThan(installed),
        isTrue,
      );
    });

    test('a lower name is never newer', () {
      expect(
        const AppVersion(1, 2, 2, build: 99).isNewerThan(installed),
        isFalse,
      );
      expect(const AppVersion(0, 9, 9).isNewerThan(installed), isFalse);
    });

    test('with the same name, a higher build number is newer', () {
      expect(
        const AppVersion(1, 2, 3, build: 11).isNewerThan(installed),
        isTrue,
      );
      expect(
        const AppVersion(1, 2, 3, build: 10).isNewerThan(installed),
        isFalse,
      );
      expect(
        const AppVersion(1, 2, 3, build: 9).isNewerThan(installed),
        isFalse,
      );
    });

    test('with the same name, a missing build number is not newer', () {
      expect(const AppVersion(1, 2, 3).isNewerThan(installed), isFalse);
      expect(
        const AppVersion(
          1,
          2,
          3,
          build: 11,
        ).isNewerThan(const AppVersion(1, 2, 3)),
        isFalse,
      );
    });
  });
}
