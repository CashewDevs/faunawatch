import 'dart:async';
import 'dart:io';

import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/community_map/models/map_post_preview.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_post_dialog.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_post_flip_transition.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../feed/fake_feed_service.dart';

const _url = 'https://photos.invalid/first.webp';
const _preview = MapPostPreview(
  id: 'r1',
  title: 'Animal in need',
  author: 'Community spotter',
  location: 'Approximate location',
  body: 'Bird near the road.',
);

void main() {
  Future<void> pumpDialog(
    WidgetTester tester,
    FeedService service, {
    bool reducedMotion = false,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [feedServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reducedMotion),
          child: child!,
        ),
        home: Scaffold(
          body: MapPostFlipTransition(
            animation: const AlwaysStoppedAnimation(1),
            builder: (onReady) => MapPostDialog(
              preview: _preview,
              onSeeMore: () {},
              onThumbnailReady: onReady,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('shows the first post photo above its details', (tester) async {
    final asset = await rootBundle.load(AppAssets.avatarPanda);
    final client = _ImageClient(asset.buffer.asUint8List());
    debugNetworkImageHttpClientProvider = () => client;
    try {
      await pumpDialog(
        tester,
        FakeFeedService(
          posts: [
            testPost('r1', photoUrls: [_url, 'unused-second-photo']),
          ],
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await precacheImage(
          const NetworkImage(_url),
          tester.element(find.byType(MapPostDialog, skipOffstage: false)),
        );
      });
      await tester.pumpAndSettle();
      final photo = tester.widget<Image>(find.byType(Image));
      expect((photo.image as NetworkImage).url, _url);
      expect(photo.fit, BoxFit.cover);
      expect(photo.semanticLabel, 'Post thumbnail');
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(
        tester.getRect(find.byType(Image)).bottom,
        lessThan(tester.getRect(find.text('Approved wildlife report')).top),
      );
      expect(find.text('Bird near the road.'), findsOneWidget);
      expect(find.text('See more in feed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugNetworkImageHttpClientProvider = null;
      PaintingBinding.instance.imageCache.clear();
    }
  });

  testWidgets('shows loading, then a placeholder for a post without photos', (
    tester,
  ) async {
    final service = _Feed()..pending = Completer<FeedPost?>();
    await pumpDialog(tester, service);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading post preview…'), findsOneWidget);
    expect(find.text('Bird near the road.'), findsNothing);
    service.pending!.complete(testPost('r1'));
    await tester.pumpAndSettle();
    expect(find.text('No photo attached'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed lookup offers retry without losing report details', (
    tester,
  ) async {
    final service = _Feed()..fail = true;
    await pumpDialog(tester, service);
    await tester.pumpAndSettle();
    expect(find.text('Could not load photo'), findsOneWidget);
    expect(find.text('Bird near the road.'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Retry photo'));
    await tester.pumpAndSettle();
    expect(find.text('No photo attached'), findsOneWidget);
    expect(find.text('See more in feed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion still waits for loading and reveals without a flip',
    (tester) async {
      final service = _Feed()..pending = Completer<FeedPost?>();
      await pumpDialog(tester, service, reducedMotion: true);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Loading post preview…'), findsOneWidget);
      expect(find.text('Bird near the road.'), findsNothing);
      service.pending!.complete(testPost('r1'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Bird near the road.'), findsOneWidget);
      expect(find.text('Loading post preview…'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loading can finish safely after dismissing the preview', (
    tester,
  ) async {
    final service = _Feed()..pending = Completer<FeedPost?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [feedServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => MapPostFlipTransition(
                    animation: const AlwaysStoppedAnimation(1),
                    builder: (onReady) => MapPostDialog(
                      preview: _preview,
                      onSeeMore: () {},
                      onThumbnailReady: onReady,
                    ),
                  ),
                ),
                child: const Text('Open preview'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open preview'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Loading post preview…'), findsOneWidget);
    await tester.tap(find.byTooltip('Close post preview'));
    await tester.pumpAndSettle();
    service.pending!.complete(testPost('r1'));
    await tester.pumpAndSettle();
    expect(find.byType(MapPostDialog), findsNothing);
    expect(find.text('Open preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed image download keeps the preview usable', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      FakeFeedService(
        posts: [
          testPost('r1', photoUrls: [_url]),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Photo unavailable'), findsOneWidget);
    expect(find.text('Retry photo'), findsOneWidget);
    expect(find.text('See more in feed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('waits for downloaded image pixels before flipping to the post', (
    tester,
  ) async {
    final asset = await rootBundle.load(AppAssets.avatarPanda);
    final download = Completer<void>();
    debugNetworkImageHttpClientProvider = () =>
        _DelayedImageClient(asset.buffer.asUint8List(), download.future);
    try {
      await pumpDialog(
        tester,
        FakeFeedService(
          posts: [
            testPost('r1', photoUrls: [_url]),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Loading post preview…'), findsOneWidget);
      expect(find.text('Bird near the road.'), findsNothing);
      expect(find.byType(Image, skipOffstage: false), findsOneWidget);

      await tester.runAsync(() async {
        download.complete();
        await precacheImage(
          const NetworkImage(_url),
          tester.element(find.byType(MapPostDialog, skipOffstage: false)),
        );
      });
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Loading post preview…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Bird near the road.'), findsOneWidget);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugNetworkImageHttpClientProvider = null;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
  });
}

class _Feed extends FakeFeedService {
  Completer<FeedPost?>? pending;
  bool fail = false;

  @override
  Future<FeedPost?> fetchPost(String postId) async {
    if (fail) throw StateError('offline');
    return pending?.future ?? testPost(postId);
  }
}

class _ImageClient implements HttpClient {
  _ImageClient(this.bytes);
  final Uint8List bytes;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _ImageRequest(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedImageClient extends _ImageClient {
  _DelayedImageClient(super.bytes, this.download);
  final Future<void> download;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    await download;
    return super.getUrl(url);
  }
}

class _ImageRequest implements HttpClientRequest {
  _ImageRequest(this.bytes);
  final Uint8List bytes;

  @override
  Future<HttpClientResponse> close() async => _ImageResponse(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  _ImageResponse(this.bytes);
  final Uint8List bytes;

  @override
  int get statusCode => HttpStatus.ok;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
