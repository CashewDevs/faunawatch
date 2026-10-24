import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';
import 'package:faunawatch/features/notifications/services/notifications_service.dart';
import 'package:faunawatch/features/notifications/views/notifications_view.dart';
import 'package:faunawatch/features/notifications/views/widgets/notification_action_sheet.dart';
import 'package:faunawatch/features/notifications/views/widgets/notification_tile.dart';
import 'package:faunawatch/features/notifications/views/widgets/notifications_filter_chips.dart';
import 'package:faunawatch/features/notifications/views/widgets/notifications_header.dart';
import 'package:faunawatch/features/shell/views/shell_view.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildTestNotificationsView({List<NotificationItem>? initialItems}) {
    return ProviderScope(
      overrides: [
        if (initialItems != null)
          notificationsServiceProvider.overrideWithValue(
            FaunaNotificationsService(initialItems: initialItems),
          ),
      ],
      child: const MaterialApp(home: NotificationsView()),
    );
  }

  group('NotificationsView Widgets and Visual Hierarchy', () {
    testWidgets(
      'renders NotificationsHeader with gradient and extrabold title',
      (tester) async {
        await tester.pumpWidget(buildTestNotificationsView());
        await tester.pumpAndSettle();

        expect(find.byType(NotificationsHeader), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);

        final headerFinder = find.byType(NotificationsHeader);
        final container = tester.widget<Container>(
          find
              .descendant(of: headerFinder, matching: find.byType(Container))
              .first,
        );
        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.gradient, isA<LinearGradient>());
        final gradient = decoration!.gradient as LinearGradient;
        expect(gradient.begin, Alignment.centerLeft);
        expect(gradient.end, Alignment.centerRight);
        expect(gradient.colors.first, AppColors.messagesHeaderGradientStart);
        expect(gradient.colors.last, AppColors.messagesHeaderGradientEnd);
      },
    );

    testWidgets('renders filter chips with All and Unread options', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestNotificationsView());
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsFilterChips), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
    });

    testWidgets(
      'unread notification has #FFFBE9 background and #FECE01 left bar',
      (tester) async {
        const items = [
          NotificationItem(
            id: '1',
            title: 'Unread Alert',
            message: 'Some unread details',
            timestamp: '2m ago',
            isUnread: true,
          ),
          NotificationItem(
            id: '2',
            title: 'Read Alert',
            message: 'Some read details',
            timestamp: '1h ago',
            isUnread: false,
          ),
        ];

        await tester.pumpWidget(
          buildTestNotificationsView(initialItems: items),
        );
        await tester.pumpAndSettle();

        expect(find.byType(NotificationTile), findsNWidgets(2));

        // Locate the unread tile
        final unreadTile = find.ancestor(
          of: find.text('Unread Alert'),
          matching: find.byType(NotificationTile),
        );
        expect(unreadTile, findsOneWidget);

        // Verify unread background #FFFBE9 exists
        expect(
          find.descendant(
            of: unreadTile,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.color == AppColors.messagesUnreadBackground,
            ),
          ),
          findsOneWidget,
        );

        // Verify unread yellow accent bar #FECE01 exists
        expect(
          find.descendant(
            of: unreadTile,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.color == AppColors.messagesUnreadBar &&
                  w.constraints?.minWidth == 8,
            ),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('tapping unread notification marks it as read', (tester) async {
      const items = [
        NotificationItem(
          id: '1',
          title: 'Unread Alert',
          message: 'Some unread details',
          timestamp: '2m ago',
          isUnread: true,
        ),
      ];

      await tester.pumpWidget(buildTestNotificationsView(initialItems: items));
      await tester.pumpAndSettle();

      // Initially has unread bar
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.color == AppColors.messagesUnreadBar &&
              w.constraints?.minWidth == 8,
        ),
        findsOneWidget,
      );

      // Tap the notification
      await tester.tap(find.text('Unread Alert'));
      await tester.pumpAndSettle();

      // Yellow unread bar should now be gone
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.color == AppColors.messagesUnreadBar &&
              w.constraints?.minWidth == 8,
        ),
        findsNothing,
      );
    });

    testWidgets('filtering by Unread shows only unread notifications', (
      tester,
    ) async {
      const items = [
        NotificationItem(
          id: '1',
          title: 'Unread Alert',
          message: 'Some unread details',
          timestamp: '2m ago',
          isUnread: true,
        ),
        NotificationItem(
          id: '2',
          title: 'Read Notice',
          message: 'Some read details',
          timestamp: '1h ago',
          isUnread: false,
        ),
      ];

      await tester.pumpWidget(buildTestNotificationsView(initialItems: items));
      await tester.pumpAndSettle();

      expect(find.text('Unread Alert'), findsOneWidget);
      expect(find.text('Read Notice'), findsOneWidget);

      // Tap "Unread" chip
      await tester.tap(find.text('Unread'));
      await tester.pumpAndSettle();

      expect(find.text('Unread Alert'), findsOneWidget);
      expect(find.text('Read Notice'), findsNothing);

      // Tap "All" chip
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('Unread Alert'), findsOneWidget);
      expect(find.text('Read Notice'), findsOneWidget);
    });

    testWidgets(
      'long press opens modal option sheet to mark as read/unread or delete',
      (tester) async {
        const items = [
          NotificationItem(
            id: '1',
            title: 'Long Press Me',
            message: 'Details for modal action',
            timestamp: '5m ago',
            isUnread: true,
          ),
        ];

        await tester.pumpWidget(
          buildTestNotificationsView(initialItems: items),
        );
        await tester.pumpAndSettle();

        // Long press the notification
        await tester.longPress(find.text('Long Press Me'));
        await tester.pumpAndSettle();

        // Modal options should appear
        expect(find.byType(NotificationActionSheet), findsOneWidget);
        expect(find.text('Mark as read'), findsOneWidget);
        expect(find.text('Delete notification'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        // Tap "Mark as read"
        await tester.tap(find.text('Mark as read'));
        await tester.pumpAndSettle();

        // Sheet dismissed and item is now read
        expect(find.byType(NotificationActionSheet), findsNothing);

        // Long press again on now-read item
        await tester.longPress(find.text('Long Press Me'));
        await tester.pumpAndSettle();

        // Should now offer "Mark as unread"
        expect(find.text('Mark as unread'), findsOneWidget);

        // Tap "Delete notification"
        await tester.tap(find.text('Delete notification'));
        await tester.pumpAndSettle();

        // Item should be completely deleted
        expect(find.text('Long Press Me'), findsNothing);
        expect(find.text('No notifications'), findsOneWidget);
      },
    );
  });

  group('ShellNavBar Notification Red Badge Integration', () {
    testWidgets(
      'red circle badge appears on Notifs nav bar icon when unread notifications exist and disappears when read or deleted',
      (tester) async {
        const items = [
          NotificationItem(
            id: 'n1',
            title: 'Badge Alert',
            message: 'Has unread',
            timestamp: 'Now',
            isUnread: true,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationsServiceProvider.overrideWithValue(
                FaunaNotificationsService(initialItems: items),
              ),
            ],
            child: const MaterialApp(home: ShellView()),
          ),
        );
        await tester.pumpAndSettle();

        // Check badge exists on navbar
        expect(find.byKey(const Key('notifs_red_badge')), findsOneWidget);

        // Navigate to Notifs tab
        await tester.tap(find.text('Notifs'));
        await tester.pumpAndSettle();

        // Tap the notification to mark it as read
        await tester.tap(find.text('Badge Alert'));
        await tester.pumpAndSettle();

        // Badge should disappear!
        expect(find.byKey(const Key('notifs_red_badge')), findsNothing);
      },
    );
  });
}
