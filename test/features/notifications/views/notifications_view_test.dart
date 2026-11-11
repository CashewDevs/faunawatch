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
import 'package:faunawatch/features/profile_customization/viewmodels/profile_picture_viewmodel.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';
import 'package:faunawatch/features/shell/views/widgets/shell_nav_bar.dart';
import '../fake_notifications_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildTestNotificationsView({
    List<NotificationItem> initialItems = const [],
    FakeNotificationsService? service,
    double bottomInset = 0,
  }) {
    return ProviderScope(
      overrides: [
        notificationsServiceProvider.overrideWithValue(
          service ?? FakeNotificationsService(items: initialItems),
        ),
      ],
      child: MaterialApp(
        // Stands in for the floating nav bar the shell draws over the body.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: EdgeInsets.only(bottom: bottomInset)),
          child: child!,
        ),
        home: const NotificationsView(),
      ),
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

  group('NotificationsView states', () {
    testWidgets('shows a loading indicator until the list arrives', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestNotificationsView(
          initialItems: const [
            NotificationItem(
              id: '1',
              title: 'Loaded',
              message: 'Details',
              timestamp: '1m ago',
            ),
          ],
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loaded'), findsNothing);

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Loaded'), findsOneWidget);
    });

    testWidgets('shows an empty message when there are no notifications', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestNotificationsView());
      await tester.pumpAndSettle();

      expect(find.text('No notifications'), findsOneWidget);
      expect(
        find.text(
          "You're all caught up. Updates on your reports, comments and chats "
          'will show up here.',
        ),
        findsOneWidget,
      );
      expect(find.byType(NotificationTile), findsNothing);
    });

    testWidgets('keeps the unread empty title with a short subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestNotificationsView());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unread'));
      await tester.pumpAndSettle();

      expect(find.text('No unread notifications'), findsOneWidget);
      expect(find.text("You're all caught up."), findsOneWidget);
    });

    testWidgets('centres the empty state above the nav bar inset', (
      tester,
    ) async {
      const inset = 100.0;
      await tester.pumpWidget(buildTestNotificationsView(bottomInset: inset));
      await tester.pumpAndSettle();

      final area = find.byType(RefreshIndicator);
      final visibleCentre =
          tester.getTopLeft(area).dy +
          (tester.getSize(area).height - inset) / 2;
      final content = find.descendant(of: area, matching: find.byType(Column));
      final contentCentre = tester.getCenter(content.first).dy;

      expect(contentCentre, closeTo(visibleCentre, 1));
    });

    testWidgets('centres the error state above the nav bar inset', (
      tester,
    ) async {
      const inset = 100.0;
      final service = FakeNotificationsService()..failLoading = true;
      await tester.pumpWidget(
        buildTestNotificationsView(service: service, bottomInset: inset),
      );
      await tester.pumpAndSettle();

      final area = find.byType(RefreshIndicator);
      final visibleCentre =
          tester.getTopLeft(area).dy +
          (tester.getSize(area).height - inset) / 2;
      final content = find.descendant(of: area, matching: find.byType(Column));

      expect(find.text('Try again'), findsOneWidget);
      expect(tester.getCenter(content.first).dy, closeTo(visibleCentre, 1));
    });

    testWidgets('scrolls instead of overflowing on a short screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 380);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(buildTestNotificationsView(bottomInset: 80));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('No notifications'), findsOneWidget);
    });

    testWidgets('can be pulled to refresh while empty', (tester) async {
      final service = FakeNotificationsService();
      await tester.pumpWidget(buildTestNotificationsView(service: service));
      await tester.pumpAndSettle();
      final loadsBefore = service.loads;

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(service.loads, greaterThan(loadsBefore));
      expect(find.text('No notifications'), findsOneWidget);
    });

    testWidgets('shows an unread-specific empty message under the filter', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestNotificationsView(
          initialItems: const [
            NotificationItem(
              id: '1',
              title: 'Read one',
              message: 'Details',
              timestamp: '1h ago',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unread'));
      await tester.pumpAndSettle();

      expect(find.text('No unread notifications'), findsOneWidget);
    });

    testWidgets('shows an error with Try again that reloads', (tester) async {
      final service = FakeNotificationsService(
        items: const [
          NotificationItem(
            id: '1',
            title: 'Recovered',
            message: 'Details',
            timestamp: '1m ago',
          ),
        ],
      )..failLoading = true;
      await tester.pumpWidget(buildTestNotificationsView(service: service));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not load notifications'),
        findsOneWidget,
      );
      expect(find.text('No notifications'), findsNothing);

      service.failLoading = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Recovered'), findsOneWidget);
      expect(find.textContaining('Could not load notifications'), findsNothing);
    });

    testWidgets('shows the relative time and a new live notification', (
      tester,
    ) async {
      final service = FakeNotificationsService(
        items: [
          NotificationItem(
            id: '1',
            title: 'Older',
            message: 'Details',
            timestamp: '',
            createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
        ],
      );
      await tester.pumpWidget(buildTestNotificationsView(service: service));
      await tester.pumpAndSettle();

      expect(find.text('5m ago'), findsOneWidget);

      service.items.insert(
        0,
        NotificationItem(
          id: '2',
          title: 'Brand new',
          message: 'Details',
          timestamp: '',
          isUnread: true,
          createdAt: DateTime.now(),
        ),
      );
      service.emitLive();
      await tester.pumpAndSettle();

      expect(find.text('Brand new'), findsOneWidget);
      expect(find.text('Just now'), findsOneWidget);
    });

    testWidgets('keeps the list and shows a banner when live updates drop', (
      tester,
    ) async {
      final service = FakeNotificationsService(
        items: const [
          NotificationItem(
            id: '1',
            title: 'Still here',
            message: 'Details',
            timestamp: '1m ago',
          ),
        ],
      );
      await tester.pumpWidget(buildTestNotificationsView(service: service));
      await tester.pumpAndSettle();

      service.emitLiveError();
      await tester.pumpAndSettle();

      expect(find.text('Still here'), findsOneWidget);
      expect(find.textContaining('Live updates disconnected'), findsOneWidget);
    });

    testWidgets('loads older notifications on request', (tester) async {
      final service = FakeNotificationsService(
        items: [
          for (var i = 0; i < 55; i++)
            NotificationItem(
              id: 'n${i.toString().padLeft(2, '0')}',
              title: 'Item $i',
              message: 'Details',
              timestamp: '1h ago',
            ),
        ],
      );
      await tester.pumpWidget(buildTestNotificationsView(service: service));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Load older notifications'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Load older notifications'));
      await tester.pumpAndSettle();

      expect(find.text('Load older notifications'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Item 54'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Item 54'), findsOneWidget);
    });

    testWidgets('each notification type has its own icon', (tester) async {
      // Tall enough that every row is built.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildTestNotificationsView(
          initialItems: [
            for (final type in NotificationType.values)
              NotificationItem(
                id: type.name,
                title: 'Type ${type.name}',
                message: 'Details',
                timestamp: '1h ago',
                type: type,
              ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    });
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

        // The nav bar next to the notifications list, without the other
        // shell tabs (which need Supabase and Mapbox). The nav bar also reads
        // the profile picture state, so that ViewModel is faked.
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationsServiceProvider.overrideWithValue(
                FakeNotificationsService(items: items),
              ),
              profilePictureViewModelProvider.overrideWith(
                _FakeProfilePictureViewModel.new,
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: const NotificationsView(),
                bottomNavigationBar: ShellNavBar(
                  currentDestination: ShellDestination.notifs,
                  onSelectDestination: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check badge exists on navbar
        expect(find.byKey(const Key('notifs_red_badge')), findsOneWidget);

        // Tap the notification to mark it as read
        await tester.tap(find.text('Badge Alert'));
        await tester.pumpAndSettle();

        // Badge should disappear!
        expect(find.byKey(const Key('notifs_red_badge')), findsNothing);
      },
    );
  });
}

class _FakeProfilePictureViewModel extends ProfilePictureViewModel {
  @override
  ProfilePictureState build() => const ProfilePictureState();
}
