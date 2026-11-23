import 'dart:async';
import 'dart:io';

import 'package:faunawatch/features/app_update/services/app_update_installer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('faunawatch/app_update');
  final url = Uri.parse('https://example.com/faunawatch.apk');
  late Directory dir;
  late List<MethodCall> calls;
  Object? Function(MethodCall call) answer = (_) => null;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fw_updates_test');
    calls = [];
    answer = (call) => call.method == 'updateDir' ? dir.path : null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return answer(call);
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  AndroidAppUpdateInstaller installerFor(
    Future<http.StreamedResponse> Function(http.BaseRequest request) respond,
  ) => AndroidAppUpdateInstaller(
    MockClient.streaming((request, _) => respond(request)),
  );

  List<String> filesIn(Directory directory) =>
      directory.listSync().map((entry) => entry.uri.pathSegments.last).toList();

  group('download', () {
    test('saves the file and reports progress', () async {
      final progress = <double?>[];
      late http.BaseRequest sent;
      final installer = installerFor((request) async {
        sent = request;
        return http.StreamedResponse(
          Stream.fromIterable([
            [1, 2],
            [3, 4],
          ]),
          200,
          contentLength: 4,
        );
      });

      final path = await installer.download(url, onProgress: progress.add);

      expect(sent.url, url);
      expect(path, endsWith(AndroidAppUpdateInstaller.fileName));
      expect(await File(path).readAsBytes(), [1, 2, 3, 4]);
      expect(progress, [0, 0.5, 1]);
      expect(filesIn(dir), [AndroidAppUpdateInstaller.fileName]);
    });

    test('reports unknown progress when the size is unknown', () async {
      final progress = <double?>[];
      final installer = installerFor(
        (_) async => http.StreamedResponse(
          Stream.fromIterable([
            [1, 2, 3],
          ]),
          200,
        ),
      );

      final path = await installer.download(url, onProgress: progress.add);

      expect(await File(path).readAsBytes(), [1, 2, 3]);
      expect(progress, [null]);
    });

    test('replaces an older download', () async {
      await File(
        '${dir.path}/${AndroidAppUpdateInstaller.fileName}',
      ).writeAsBytes([9, 9, 9, 9, 9]);
      final installer = installerFor(
        (_) async => http.StreamedResponse(
          Stream.fromIterable([
            [7],
          ]),
          200,
          contentLength: 1,
        ),
      );

      final path = await installer.download(url, onProgress: (_) {});

      expect(await File(path).readAsBytes(), [7]);
    });

    test('fails on an error answer and leaves no file', () async {
      final installer = installerFor(
        (_) async => http.StreamedResponse(const Stream.empty(), 404),
      );

      await expectLater(
        installer.download(url, onProgress: (_) {}),
        throwsA(
          isA<AppUpdateInstallException>().having(
            (error) => error.failure,
            'failure',
            AppUpdateInstallFailure.downloadFailed,
          ),
        ),
      );
      expect(filesIn(dir), isEmpty);
    });

    test('fails when the connection drops halfway', () async {
      final installer = installerFor(
        (_) async => http.StreamedResponse(
          Stream.fromIterable([
            [1, 2],
          ]),
          200,
          contentLength: 4,
        ),
      );

      await expectLater(
        installer.download(url, onProgress: (_) {}),
        throwsA(isA<AppUpdateInstallException>()),
      );
      expect(filesIn(dir), isEmpty);
    });

    test('fails when offline', () async {
      final installer = installerFor(
        (_) async => throw const SocketException('offline'),
      );

      await expectLater(
        installer.download(url, onProgress: (_) {}),
        throwsA(isA<AppUpdateInstallException>()),
      );
    });

    test('stops when cancelled and leaves no file', () async {
      final body = StreamController<List<int>>();
      addTearDown(body.close);
      final cancel = Completer<void>();
      final installer = installerFor(
        (_) async => http.StreamedResponse(body.stream, 200, contentLength: 4),
      );

      final download = installer.download(
        url,
        onProgress: (_) {},
        cancel: cancel.future,
      );
      body.add([1, 2]);
      await pumpEventQueue();
      cancel.complete();

      await expectLater(download, throwsA(isA<AppUpdateDownloadCancelled>()));
      expect(filesIn(dir), isEmpty);
    });
  });

  group('Android', () {
    final installer = AndroidAppUpdateInstaller(
      MockClient((_) async => http.Response('', 200)),
    );

    test('canInstall asks Android', () async {
      answer = (call) => call.method == 'canInstall' ? true : null;
      expect(await installer.canInstall(), isTrue);

      answer = (call) => call.method == 'canInstall' ? false : null;
      expect(await installer.canInstall(), isFalse);

      answer = (_) => throw PlatformException(code: 'error');
      expect(await installer.canInstall(), isFalse);
    });

    test('openInstallSettings asks Android and ignores errors', () async {
      await installer.openInstallSettings();
      expect(calls.single.method, 'openInstallSettings');

      answer = (_) => throw PlatformException(code: 'unavailable');
      await installer.openInstallSettings();
    });

    test('install sends the path, and reports an installer error', () async {
      await installer.install('/cache/updates/faunawatch-update.apk');
      expect(calls.single.method, 'install');
      expect(calls.single.arguments, {
        'path': '/cache/updates/faunawatch-update.apk',
      });

      answer = (_) => throw PlatformException(code: 'unavailable');
      await expectLater(
        installer.install('/x.apk'),
        throwsA(
          isA<AppUpdateInstallException>().having(
            (error) => error.failure,
            'failure',
            AppUpdateInstallFailure.installFailed,
          ),
        ),
      );
    });

    test('clearDownloads empties the updates folder', () async {
      await File('${dir.path}/a.apk').writeAsBytes([1]);
      await File('${dir.path}/b.apk.part').writeAsBytes([2]);

      await installer.clearDownloads();

      expect(filesIn(dir), isEmpty);
    });
  });
}
