import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/feed/views/feed_view.dart';
import 'package:faunawatch/features/feed/views/widgets/binoculars_icon.dart';

void main() {
  group('FeedView', () {
    testWidgets('renders binoculars silhouette, title, and descriptive text', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: FeedView()));

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
