import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/create_post/services/post_photo_picker_service.dart';
import 'package:faunawatch/features/post_management/models/own_post_menu.dart';
import 'package:faunawatch/features/post_management/services/edit_post_service.dart';
import 'package:faunawatch/features/post_management/views/screens/edit_post_view.dart';
import 'package:faunawatch/features/post_management/views/widgets/own_post_options_sheet.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';
import 'package:faunawatch/features/suspension/services/suspension_service.dart';
import 'package:faunawatch/features/suspension/viewmodels/account_suspension_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../suspension/fake_suspension_service.dart';
import '../fake_edit_post_service.dart';

void main() {
  late FakeEditPostService service;
  late FakeSuspensionService suspension;

  /// A button that opens the "⋯" menu of [menu]'s post.
  Future<void> pumpMenuHost(WidgetTester tester, OwnPostMenu menu) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => Stream.value('me')),
          suspensionServiceProvider.overrideWithValue(suspension),
          editPostServiceProvider.overrideWithValue(service),
          postPhotoPickerServiceProvider.overrideWithValue(FakePhotoPicker()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                // The app's SuspensionGate keeps the suspension loaded the same way.
                ref.watch(accountSuspensionViewModelProvider);
                return TextButton(
                  onPressed: () => showOwnPostOptions(context, ref, menu),
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    service = FakeEditPostService(post: samplePost());
    suspension = FakeSuspensionService();
  });

  const approved = OwnPostMenu(postId: 'post-1', status: ReportStatus.approved);

  testWidgets('declined posts cannot be edited', (tester) async {
    await pumpMenuHost(
      tester,
      const OwnPostMenu(postId: 'post-1', status: ReportStatus.declined),
    );
    expect(find.text('Edit post'), findsNothing);
  });

  testWidgets('a suspended user is told and the editor does not open', (
    tester,
  ) async {
    suspension.active = restrictedFor7Days();
    await pumpMenuHost(tester, approved);
    await tester.tap(find.text('Edit post'));
    await tester.pumpAndSettle();
    expect(find.byType(EditPostView), findsNothing);
    expect(find.textContaining("You can't edit posts"), findsOneWidget);
  });

  testWidgets('a caption change saves and keeps the post public', (
    tester,
  ) async {
    await pumpMenuHost(tester, approved);
    await tester.tap(find.text('Edit post'));
    await tester.pumpAndSettle();
    expect(find.byType(EditPostView), findsOneWidget);
    expect(find.text('Old caption'), findsOneWidget);
    expect(find.text('Cover'), findsOneWidget);
    expect(find.text('Your post stays public.'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Save changes');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'New caption');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(service.captions, ['New caption']);
    expect(find.byType(EditPostView), findsNothing);
    expect(find.text('Changes saved.'), findsOneWidget);
  });

  testWidgets('a new cover asks for the AI first and warns about review', (
    tester,
  ) async {
    await pumpMenuHost(tester, approved);
    await tester.tap(find.text('Edit post'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Make cover'));
    await tester.pumpAndSettle();
    expect(find.text('Analyze with AI'), findsOneWidget);
    expect(
      find.textContaining('sends your post back for review'),
      findsOneWidget,
    );
    final save = find.widgetWithText(FilledButton, 'Save and send for review');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    // Back to the old cover: nothing left to analyse or save.
    await tester.tap(find.byTooltip('Make cover'));
    await tester.pumpAndSettle();
    expect(find.text('Analyze with AI'), findsNothing);
    expect(find.text('Your post stays public.'), findsOneWidget);
  });

  testWidgets('removing a photo needs no AI and can be saved for review', (
    tester,
  ) async {
    await pumpMenuHost(tester, approved);
    await tester.tap(find.text('Edit post'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove photo'));
    await tester.pumpAndSettle();
    expect(find.text('Analyze with AI'), findsNothing);
    final save = find.widgetWithText(FilledButton, 'Save and send for review');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(service.replaced.single.$1, [coverPhoto]);
    expect(
      find.text('Changes saved. Your post is back once an admin approves it.'),
      findsOneWidget,
    );
  });

  testWidgets('leaving with changes asks first', (tester) async {
    await pumpMenuHost(tester, approved);
    await tester.tap(find.text('Edit post'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Changed');
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(EditPostView), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(EditPostView), findsNothing);
    expect(service.captions, isEmpty);
  });
}
