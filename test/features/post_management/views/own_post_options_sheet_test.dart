import 'package:faunawatch/features/post_management/models/own_post_menu.dart';
import 'package:faunawatch/features/post_management/services/post_management_service.dart';
import 'package:faunawatch/features/post_management/views/widgets/own_post_options_sheet.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_post_management_service.dart';

void main() {
  late FakePostManagementService service;
  late int deletedCallbacks;

  Future<void> openMenu(WidgetTester tester, OwnPostMenu menu) async {
    service = FakePostManagementService();
    deletedCallbacks = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [postManagementServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showOwnPostOptions(
                  context,
                  ref,
                  menu,
                  onDeleted: () => deletedCallbacks++,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  const approved = OwnPostMenu(postId: 'a', status: ReportStatus.approved);

  testWidgets('an approved post can be hidden, with Undo', (tester) async {
    await openMenu(tester, approved);
    expect(find.text('Show post again'), findsNothing);
    await tester.tap(find.text('Hide post'));
    await tester.pumpAndSettle();
    expect(service.hiddenCalls, [('a', true)]);
    expect(
      find.text('Post hidden. Only you can see it, on your profile.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(service.hiddenCalls, [('a', true), ('a', false)]);
  });

  testWidgets('a hidden post can be shown again', (tester) async {
    await openMenu(
      tester,
      const OwnPostMenu(
        postId: 'a',
        status: ReportStatus.approved,
        isHidden: true,
      ),
    );
    expect(find.text('Hide post'), findsNothing);
    expect(find.text('Everyone can see it again.'), findsOneWidget);
    await tester.tap(find.text('Show post again'));
    await tester.pumpAndSettle();
    expect(service.hiddenCalls, [('a', false)]);
    expect(find.text('Post shown again.'), findsOneWidget);
  });

  testWidgets('pending and declined posts can only be deleted', (tester) async {
    for (final status in [ReportStatus.pending, ReportStatus.declined]) {
      await openMenu(tester, OwnPostMenu(postId: 'a', status: status));
      expect(find.text('Hide post'), findsNothing);
      expect(find.text('Show post again'), findsNothing);
      expect(find.text('Delete post'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('delete asks first; Cancel keeps the post', (tester) async {
    await openMenu(tester, approved);
    await tester.tap(find.text('Delete post'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this post?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.deleted, isEmpty);
    expect(deletedCallbacks, 0);
  });

  testWidgets('confirming deletes the post and tells the screen', (
    tester,
  ) async {
    await openMenu(tester, approved);
    await tester.tap(find.text('Delete post'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(service.deleted, ['a']);
    expect(deletedCallbacks, 1);
    expect(find.text('Post deleted.'), findsOneWidget);
  });

  testWidgets('a failure is explained and nothing else happens', (
    tester,
  ) async {
    await openMenu(tester, approved);
    service.error = const PostActionException(PostActionFailure.notFound);
    await tester.tap(find.text('Delete post'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text(PostActionFailure.notFound.message), findsOneWidget);
    expect(deletedCallbacks, 0);
  });
}
