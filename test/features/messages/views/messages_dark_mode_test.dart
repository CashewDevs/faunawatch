import '../fake_messages_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/messages/models/chat_message.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';
import 'package:faunawatch/features/messages/services/messages_service.dart';
import 'package:faunawatch/features/messages/views/chat_conversation_view.dart';
import 'package:faunawatch/features/messages/views/messages_view.dart';
import 'package:faunawatch/features/messages/views/new_chat_view.dart';
import 'package:faunawatch/features/messages/views/widgets/chat_bubble.dart';
import 'package:faunawatch/features/messages/views/widgets/chat_header.dart';
import 'package:faunawatch/features/messages/views/widgets/chat_input_bar.dart';
import 'package:faunawatch/features/messages/views/widgets/message_action_sheet.dart';
import 'package:faunawatch/features/messages/views/widgets/message_tile.dart';
import 'package:faunawatch/features/messages/views/widgets/messages_filter_chips.dart';
import 'package:faunawatch/features/messages/views/widgets/messages_header.dart';
import 'package:faunawatch/features/messages/views/widgets/messages_search_bar.dart';

class _DarkModeService extends FakeMessagesService {
  @override
  Future<List<MessageThread>> fetchMessageThreads() async => const [
    MessageThread(
      id: 'thread-1',
      senderName: 'Ranger Dave',
      lastMessage: 'Eagle sighting photo uploaded',
      timestamp: '10:42 AM',
      isUnread: false,
    ),
    MessageThread(
      id: 'thread-2',
      senderName: 'Wildlife Rescue Team',
      lastMessage: 'Injured barn owl reported',
      timestamp: 'Just now',
      isUnread: true,
    ),
  ];

  @override
  Future<List<ChatMessage>> fetchChatMessages(
    String threadId, {
    ChatMessage? before,
  }) async => const [
    ChatMessage(
      id: 'msg-1',
      text: 'Other user message',
      isUser: false,
      timestamp: '10:00 AM',
    ),
    ChatMessage(
      id: 'msg-2',
      text: 'Current user message',
      isUser: true,
      timestamp: '10:02 AM',
    ),
  ];

  @override
  Future<bool> markAsRead(String threadId, {String? throughMessageId}) async =>
      true;

  @override
  Future<bool> markAsUnread(String threadId) async => true;

  @override
  Future<bool> deleteThread(String threadId) async => true;

  @override
  Future<ChatMessage> sendMessage({
    required String threadId,
    required String text,
    ChatPhoto? photo,
  }) async =>
      ChatMessage(id: 'sent', text: text, isUser: true, timestamp: 'Now');
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const thread = MessageThread(
    id: 'thread-test',
    senderName: 'Ranger Dave',
    lastMessage: 'Latest report',
    timestamp: '1h ago',
  );

  Widget build(Widget home, ThemeMode themeMode) {
    return ProviderScope(
      overrides: [
        messagesServiceProvider.overrideWithValue(_DarkModeService()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: home,
      ),
    );
  }

  Color? scaffoldColor(WidgetTester tester, Type view) => tester
      .widget<Scaffold>(
        find.descendant(of: find.byType(view), matching: find.byType(Scaffold)),
      )
      .backgroundColor;

  LinearGradient headerGradient(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(MessagesHeader),
            matching: find.byType(Container),
          )
          .first,
    );
    return (container.decoration! as BoxDecoration).gradient! as LinearGradient;
  }

  Color? tileColor(WidgetTester tester, String name) {
    final tile = find.ancestor(
      of: find.text(name),
      matching: find.byType(MessageTile),
    );
    return tester
        .widget<Container>(
          find.descendant(of: tile, matching: find.byType(Container)).first,
        )
        .color;
  }

  Color? textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  LinearGradient bubbleGradient(WidgetTester tester, String text) {
    final bubble = find.ancestor(
      of: find.text(text),
      matching: find.byType(ChatBubble),
    );
    final container = tester.widget<Container>(
      find.descendant(of: bubble, matching: find.byType(Container)).first,
    );
    return (container.decoration! as BoxDecoration).gradient! as LinearGradient;
  }

  Color? decorationColor(WidgetTester tester, Type widget) {
    final container = tester.widget<Container>(
      find
          .descendant(of: find.byType(widget), matching: find.byType(Container))
          .first,
    );
    return (container.decoration! as BoxDecoration).color;
  }

  group('Inbox in dark mode', () {
    testWidgets('uses dark scaffold, header, search bar and chips', (
      tester,
    ) async {
      await tester.pumpWidget(build(const MessagesView(), ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(scaffoldColor(tester, MessagesView), AppColors.darkBackground);
      expect(headerGradient(tester).colors, [
        AppColors.darkHeaderGradientStart,
        AppColors.darkHeaderGradientEnd,
      ]);
      expect(textColor(tester, 'Messages'), AppColors.darkAccentBlue);
      expect(decorationColor(tester, MessagesSearchBar), AppColors.darkSurface);

      Color? chipColor(String label) {
        final chip = find.descendant(
          of: find.byType(MessagesFilterChips),
          matching: find.ancestor(
            of: find.text(label),
            matching: find.byType(Container),
          ),
        );
        return (tester.widget<Container>(chip.first).decoration!
                as BoxDecoration)
            .color;
      }

      expect(chipColor('All'), AppColors.darkFilterSelected);
      expect(chipColor('Unread'), AppColors.darkSurface);
    });

    testWidgets('unread and read rows have distinct dark styling', (
      tester,
    ) async {
      await tester.pumpWidget(build(const MessagesView(), ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(
        tileColor(tester, 'Wildlife Rescue Team'),
        AppColors.darkUnreadBackground,
      );
      expect(tileColor(tester, 'Ranger Dave'), Colors.transparent);
      expect(
        textColor(tester, 'Wildlife Rescue Team'),
        AppColors.darkTextPrimary,
      );
      expect(textColor(tester, 'Ranger Dave'), AppColors.darkTextBody);
      expect(
        textColor(tester, 'Eagle sighting photo uploaded'),
        AppColors.darkTextSecondary,
      );
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Wildlife Rescue Team'),
            matching: find.byType(MessageTile),
          ),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.color == AppColors.messagesUnreadBar,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('follows the platform brightness with ThemeMode.system', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(build(const MessagesView(), ThemeMode.system));
      await tester.pumpAndSettle();

      expect(scaffoldColor(tester, MessagesView), AppColors.darkBackground);
    });

    testWidgets('action sheet uses the dark surface', (tester) async {
      await tester.pumpWidget(build(const MessagesView(), ThemeMode.dark));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Wildlife Rescue Team'));
      await tester.pumpAndSettle();

      expect(
        decorationColor(tester, MessageActionSheet),
        AppColors.darkSurface,
      );
      expect(textColor(tester, 'Mark as read'), AppColors.darkTextPrimary);
      expect(textColor(tester, 'Delete conversation'), AppColors.darkErrorText);
    });

    testWidgets('new chat screen follows the dark theme', (tester) async {
      await tester.pumpWidget(build(const NewChatView(), ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        isNull,
      );
      final context = tester.element(find.byType(NewChatView));
      expect(
        Theme.of(context).scaffoldBackgroundColor,
        AppColors.darkBackground,
      );
      expect(Theme.of(context).brightness, Brightness.dark);
    });
  });

  group('Conversation in dark mode', () {
    testWidgets('uses dark scaffold, header and input bar', (tester) async {
      await tester.pumpWidget(
        build(const ChatConversationView(thread: thread), ThemeMode.dark),
      );
      await tester.pumpAndSettle();

      expect(
        scaffoldColor(tester, ChatConversationView),
        AppColors.darkBackground,
      );
      expect(decorationColor(tester, ChatHeader), AppColors.darkSurface);
      expect(textColor(tester, 'Ranger Dave'), AppColors.darkTextPrimary);
      expect(decorationColor(tester, ChatInputBar), AppColors.darkSurface);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style?.color, AppColors.darkTextPrimary);
      expect(field.decoration?.hintStyle?.color, AppColors.darkTextSecondary);
    });

    testWidgets('sent and received bubbles use readable dark gradients', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(const ChatConversationView(thread: thread), ThemeMode.dark),
      );
      await tester.pumpAndSettle();

      expect(bubbleGradient(tester, 'Current user message').colors, [
        AppColors.darkChatUserBubbleGradientStart,
        AppColors.darkChatUserBubbleGradientEnd,
      ]);
      expect(bubbleGradient(tester, 'Other user message').colors, [
        AppColors.darkChatOtherBubbleGradientStart,
        AppColors.darkChatOtherBubbleGradientEnd,
      ]);
      expect(
        textColor(tester, 'Current user message'),
        AppColors.darkTextPrimary,
      );
      expect(
        textColor(tester, 'Other user message'),
        AppColors.darkTextPrimary,
      );

      // Light text must meet WCAG AA contrast (4.5:1) against both bubble gradients.
      for (final color in [
        AppColors.darkChatUserBubbleGradientStart,
        AppColors.darkChatUserBubbleGradientEnd,
        AppColors.darkChatOtherBubbleGradientStart,
        AppColors.darkChatOtherBubbleGradientEnd,
      ]) {
        final ratio =
            (Colors.white.computeLuminance() + 0.05) /
            (color.computeLuminance() + 0.05);
        expect(ratio, greaterThan(4.5));
      }
    });
  });

  group('Chats in light mode', () {
    testWidgets('inbox is unchanged', (tester) async {
      await tester.pumpWidget(build(const MessagesView(), ThemeMode.light));
      await tester.pumpAndSettle();

      expect(scaffoldColor(tester, MessagesView), Colors.white);
      expect(headerGradient(tester).colors, [
        AppColors.messagesHeaderGradientStart,
        AppColors.messagesHeaderGradientEnd,
      ]);
      expect(textColor(tester, 'Messages'), AppColors.messagesHeaderBlue);
      expect(decorationColor(tester, MessagesSearchBar), Colors.white);
      expect(
        tileColor(tester, 'Wildlife Rescue Team'),
        AppColors.messagesUnreadBackground,
      );
      expect(tileColor(tester, 'Ranger Dave'), Colors.transparent);
      expect(textColor(tester, 'Wildlife Rescue Team'), Colors.black87);
      expect(textColor(tester, 'Ranger Dave'), const Color(0xFF263238));
    });

    testWidgets('conversation is unchanged', (tester) async {
      await tester.pumpWidget(
        build(const ChatConversationView(thread: thread), ThemeMode.light),
      );
      await tester.pumpAndSettle();

      expect(scaffoldColor(tester, ChatConversationView), Colors.white);
      expect(
        decorationColor(tester, ChatHeader),
        AppColors.chatHeaderBackground,
      );
      expect(decorationColor(tester, ChatInputBar), Colors.white);
      expect(bubbleGradient(tester, 'Current user message').colors, [
        AppColors.chatUserBubbleGradientStart,
        AppColors.chatUserBubbleGradientEnd,
      ]);
      expect(bubbleGradient(tester, 'Other user message').colors, [
        AppColors.chatOtherBubbleGradientStart,
        AppColors.chatOtherBubbleGradientEnd,
      ]);
      expect(
        textColor(tester, 'Current user message'),
        const Color(0xFF0F1A3C),
      );
    });
  });
}
