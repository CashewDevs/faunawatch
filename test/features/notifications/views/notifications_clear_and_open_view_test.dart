import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';
import 'package:faunawatch/features/notifications/services/notifications_service.dart';
import 'package:faunawatch/features/notifications/views/notifications_view.dart';
import 'package:faunawatch/features/report_detail/views/screens/report_detail_screen.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';
import '../fake_notifications_service.dart';

NotificationItem _item(
  String id,
  NotificationType type, {
  String? reportId,
  bool unread = true,
}) => NotificationItem(
  id: id,
  title: 'Title $id',
  message: 'Body $id',
  timestamp: '1m ago',
  isUnread: unread,
  type: type,
  reportId: reportId,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeNotificationsService service;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, List<NotificationItem> items) async {
    service = FakeNotificationsService(items: items);
    container = ProviderContainer(
      overrides: [notificationsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotificationsView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Clear all is hidden while there is nothing to clear', (
    tester,
  ) async {
    await pump(tester, const []);

    expect(find.byTooltip('Notification options'), findsNothing);
  });

  testWidgets('Clear all asks first, and Cancel keeps everything', (
    tester,
  ) async {
    await pump(tester, [_item('a', NotificationType.system)]);

    // Three-dot menu lives on the same row as All and Unread (not the header).
    final menuRect = tester.getRect(find.byTooltip('Notification options'));
    final allRect = tester.getRect(find.text('All'));
    expect(menuRect.center.dy, closeTo(allRect.center.dy, 6));
    expect(
      menuRect.left,
      greaterThan(tester.getRect(find.text('Unread')).right),
    );

    await tester.tap(find.byTooltip('Notification options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(find.text('Clear all notifications?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(service.deleteAllCalls, 0);
    expect(find.text('Title a'), findsOneWidget);
  });

  testWidgets('confirming Clear all deletes everything', (tester) async {
    await pump(tester, [
      _item('a', NotificationType.system),
      _item('b', NotificationType.alert),
    ]);

    await tester.tap(find.byTooltip('Notification options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all').last);
    await tester.pumpAndSettle();

    expect(service.deleteAllCalls, 1);
    expect(find.text('Title a'), findsNothing);
    expect(find.text('No notifications'), findsOneWidget);
    expect(find.byTooltip('Notification options'), findsNothing);
  });

  testWidgets('tapping a report notification opens that report', (
    tester,
  ) async {
    await pump(tester, [
      _item('a', NotificationType.reportLike, reportId: 'r1'),
    ]);

    await tester.tap(find.text('Title a'));
    await tester.pumpAndSettle();

    final screen = tester.widget<ReportDetailScreen>(
      find.byType(ReportDetailScreen),
    );
    expect(screen.reportId, 'r1');
    expect(screen.showComments, isFalse);
    expect(service.items.single.isUnread, isFalse);
  });

  testWidgets('tapping a chat notification switches to the Messages tab', (
    tester,
  ) async {
    await pump(tester, [_item('m', NotificationType.chat)]);

    await tester.tap(find.text('Title m'));
    await tester.pumpAndSettle();

    expect(container.read(shellViewModelProvider), ShellDestination.chats);
    expect(find.byType(ReportDetailScreen), findsNothing);
    expect(service.items.single.isUnread, isFalse);
  });

  testWidgets('tapping a nearby alert only marks it read', (tester) async {
    await pump(tester, [_item('n', NotificationType.alert)]);

    await tester.tap(find.text('Title n'));
    await tester.pumpAndSettle();

    expect(container.read(shellViewModelProvider), ShellDestination.feed);
    expect(find.byType(ReportDetailScreen), findsNothing);
    expect(service.items.single.isUnread, isFalse);
  });
}
