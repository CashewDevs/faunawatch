import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';
import 'package:faunawatch/features/notifications/services/notifications_service.dart';
import 'package:faunawatch/features/notifications/views/notifications_view.dart';
import 'package:faunawatch/features/notifications/views/widgets/notification_action_sheet.dart';
import 'package:faunawatch/features/notifications/views/widgets/notification_tile.dart';
import 'package:faunawatch/features/notifications/views/widgets/notifications_filter_chips.dart';
import 'package:faunawatch/features/notifications/views/widgets/notifications_header.dart';
import '../fake_notifications_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

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

  Widget build({
    required ThemeMode themeMode,
    FakeNotificationsService? service,
  }) {
    return ProviderScope(
      overrides: [
        notificationsServiceProvider.overrideWithValue(
          service ?? FakeNotificationsService(items: items),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const NotificationsView(),
      ),
    );
  }

  Color? scaffoldColor(WidgetTester tester) => tester
      .widget<Scaffold>(
        find.descendant(
          of: find.byType(NotificationsView),
          matching: find.byType(Scaffold),
        ),
      )
      .backgroundColor;

  LinearGradient headerGradient(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(NotificationsHeader),
            matching: find.byType(Container),
          )
          .first,
    );
    return (container.decoration! as BoxDecoration).gradient! as LinearGradient;
  }

  Color? tileColor(WidgetTester tester, String title) {
    final tile = find.ancestor(
      of: find.text(title),
      matching: find.byType(NotificationTile),
    );
    return tester
        .widget<Container>(
          find.descendant(of: tile, matching: find.byType(Container)).first,
        )
        .color;
  }

  Finder yellowBar(String title) => find.descendant(
    of: find.ancestor(
      of: find.text(title),
      matching: find.byType(NotificationTile),
    ),
    matching: find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.color == AppColors.messagesUnreadBar &&
          w.constraints?.minWidth == 8,
    ),
  );

  Color? textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  group('NotificationsView in dark mode', () {
    testWidgets('uses the dark scaffold and header gradient', (tester) async {
      await tester.pumpWidget(build(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(scaffoldColor(tester), AppColors.darkBackground);
      final gradient = headerGradient(tester);
      expect(gradient.colors, [
        AppColors.darkHeaderGradientStart,
        AppColors.darkHeaderGradientEnd,
      ]);
      expect(textColor(tester, 'Notifications'), AppColors.darkAccentBlue);
    });

    testWidgets('unread tile gets a dark tint and keeps the yellow bar', (
      tester,
    ) async {
      await tester.pumpWidget(build(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(tileColor(tester, 'Unread Alert'), AppColors.darkUnreadBackground);
      expect(yellowBar('Unread Alert'), findsOneWidget);
      expect(textColor(tester, 'Unread Alert'), AppColors.darkTextPrimary);
      expect(textColor(tester, '2m ago'), AppColors.darkAccentBlue);
    });

    testWidgets('read tile stays on the dark scaffold with muted text', (
      tester,
    ) async {
      await tester.pumpWidget(build(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(tileColor(tester, 'Read Alert'), Colors.transparent);
      expect(yellowBar('Read Alert'), findsNothing);
      expect(textColor(tester, 'Read Alert'), AppColors.darkTextBody);
      expect(
        textColor(tester, 'Some read details'),
        AppColors.darkTextSecondary,
      );
      // The unread row is clearly different from the read row.
      expect(
        tileColor(tester, 'Unread Alert'),
        isNot(tileColor(tester, 'Read Alert')),
      );
      expect(AppColors.darkUnreadBackground, isNot(AppColors.darkBackground));
    });

    testWidgets('filter chips use dark surfaces', (tester) async {
      await tester.pumpWidget(build(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      Color? chipColor(String label) {
        final chip = find.descendant(
          of: find.byType(NotificationsFilterChips),
          matching: find.ancestor(
            of: find.text(label),
            matching: find.byType(Container),
          ),
        );
        return ((tester.widget<Container>(chip.first)).decoration!
                as BoxDecoration)
            .color;
      }

      expect(chipColor('All'), AppColors.darkFilterSelected);
      expect(chipColor('Unread'), AppColors.darkSurface);
    });

    testWidgets('follows the platform brightness with ThemeMode.system', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(build(themeMode: ThemeMode.system));
      await tester.pumpAndSettle();

      expect(scaffoldColor(tester), AppColors.darkBackground);
      expect(tileColor(tester, 'Unread Alert'), AppColors.darkUnreadBackground);
    });

    testWidgets('empty and error states use dark colours', (tester) async {
      await tester.pumpWidget(
        build(themeMode: ThemeMode.dark, service: FakeNotificationsService()),
      );
      await tester.pumpAndSettle();

      expect(textColor(tester, 'No notifications'), AppColors.darkTextPrimary);
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.notifications_off_outlined),
      );
      expect(icon.color, AppColors.darkIconMuted);

      final failing = FakeNotificationsService()..failLoading = true;
      await tester.pumpWidget(
        build(themeMode: ThemeMode.dark, service: failing),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Icon>(find.byIcon(Icons.cloud_off_outlined)).color,
        AppColors.darkIconMuted,
      );
    });

    testWidgets('error banner above a visible list is dark', (tester) async {
      final service = FakeNotificationsService(items: items);
      await tester.pumpWidget(
        build(themeMode: ThemeMode.dark, service: service),
      );
      await tester.pumpAndSettle();
      service.emitLiveError();
      await tester.pumpAndSettle();

      final message = find.textContaining('Live updates disconnected');
      expect(
        textColor(tester, tester.widget<Text>(message).data!),
        AppColors.darkErrorText,
      );
      final banner = tester.widget<Container>(
        find.ancestor(of: message, matching: find.byType(Container)).first,
      );
      expect(banner.color, AppColors.darkErrorBackground);
    });

    testWidgets('action sheet uses the dark surface', (tester) async {
      await tester.pumpWidget(build(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Unread Alert'));
      await tester.pumpAndSettle();

      final sheet = find.byType(NotificationActionSheet);
      final container = tester.widget<Container>(
        find.descendant(of: sheet, matching: find.byType(Container)).first,
      );
      expect(
        (container.decoration! as BoxDecoration).color,
        AppColors.darkSurface,
      );
      expect(textColor(tester, 'Mark as read'), AppColors.darkTextPrimary);
      expect(textColor(tester, 'Delete notification'), AppColors.darkErrorText);
    });
  });

  group('NotificationsView in light mode', () {
    testWidgets('is unchanged', (tester) async {
      await tester.pumpWidget(build(themeMode: ThemeMode.light));
      await tester.pumpAndSettle();

      expect(scaffoldColor(tester), Colors.white);
      expect(headerGradient(tester).colors, [
        AppColors.messagesHeaderGradientStart,
        AppColors.messagesHeaderGradientEnd,
      ]);
      expect(textColor(tester, 'Notifications'), AppColors.messagesHeaderBlue);
      expect(
        tileColor(tester, 'Unread Alert'),
        AppColors.messagesUnreadBackground,
      );
      expect(yellowBar('Unread Alert'), findsOneWidget);
      expect(tileColor(tester, 'Read Alert'), Colors.transparent);
      expect(textColor(tester, 'Unread Alert'), Colors.black87);
      expect(textColor(tester, 'Read Alert'), const Color(0xFF263238));
    });

    testWidgets('action sheet stays white', (tester) async {
      await tester.pumpWidget(build(themeMode: ThemeMode.light));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Unread Alert'));
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(NotificationActionSheet),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((container.decoration! as BoxDecoration).color, Colors.white);
      expect(textColor(tester, 'Mark as read'), const Color(0xFF1E293B));
    });
  });
}
