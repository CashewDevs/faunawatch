import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/services/window_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformWindowSecurityService', () {
    late List<MethodCall> log;
    late MethodChannel channel;
    late PlatformWindowSecurityService service;

    setUp(() {
      log = [];
      channel = const MethodChannel('faunawatch/window_security');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            log.add(call);
            return null;
          });
      service = PlatformWindowSecurityService(channel: channel);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    // Note: defaultTargetPlatform defaults to android in tests, so the
    // platform guard will allow the channel call through.
    test('enableSecure sends setSecure(true) on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await service.enableSecure();

      expect(log, hasLength(1));
      expect(log.first.method, 'setSecure');
      expect(log.first.arguments, {'secure': true});
    });

    test('disableSecure sends setSecure(false) on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await service.disableSecure();

      expect(log, hasLength(1));
      expect(log.first.method, 'setSecure');
      expect(log.first.arguments, {'secure': false});
    });

    test('does nothing on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await service.enableSecure();
      await service.disableSecure();

      expect(log, isEmpty);
    });
  });
}
