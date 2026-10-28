import 'package:flutter/material.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/feed/views/feed_view.dart';
import 'package:faunawatch/features/feed/views/widgets/binoculars_icon.dart';

void main() {
  group('FeedView', () {
    testWidgets('shows the full sample post selected from the map', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(feedViewModelProvider.notifier)
          .openSamplePost(sampleMapPost.id);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: FeedView()),
        ),
      );
      expect(find.text(sampleMapPost.title), findsOneWidget);
      expect(find.text(sampleMapPost.body), findsOneWidget);
      expect(find.text('No posts yet.'), findsNothing);
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
    });
    testWidgets('renders binoculars silhouette, title, and descriptive text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: FeedView())),
      );

      expect(find.byType(BinocularsIcon), findsOneWidget);
      expect(find.text('No posts yet.'), findsOneWidget);
      expect(
        find.text(
          'Sightings and wildlife reports in your community will appear here.',
        ),
        findsOneWidget,
      );
    });
  });
}
