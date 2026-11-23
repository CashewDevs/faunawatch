import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:faunawatch/features/app_update/services/installed_version_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformInstalledVersionService', () {
    const channel = MethodChannel('faunawatch/app_info');
    late List<MethodCall> calls;

    void answer(Object? Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return handler(call);
          });
    }

    setUp(() => calls = []);

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('reads the version name and build number on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      answer((_) => {'versionName': '1.0.0', 'versionCode': 2});

      final version = await PlatformInstalledVersionService().read();

      expect(calls.single.method, 'getVersion');
      expect(version, const AppVersion(1, 0, 0, build: 2));
    });

    test('returns null when Android sends something unreadable', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      answer((_) => {'versionName': 'dev', 'versionCode': 2});

      expect(await PlatformInstalledVersionService().read(), isNull);
    });

    test('returns null when the channel fails', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      answer((_) => throw PlatformException(code: 'unavailable'));

      expect(await PlatformInstalledVersionService().read(), isNull);
    });

    test('does not ask on other platforms', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      answer((_) => {'versionName': '1.0.0', 'versionCode': 2});

      expect(await PlatformInstalledVersionService().read(), isNull);
      expect(calls, isEmpty);
    });
  });
}
