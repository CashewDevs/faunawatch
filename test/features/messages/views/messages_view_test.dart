import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/messages/models/chat_message.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';
import 'package:faunawatch/features/messages/services/messages_service.dart';
import 'package:faunawatch/features/messages/views/chat_conversation_view.dart';
import 'package:faunawatch/features/messages/views/messages_view.dart';
import 'package:faunawatch/features/messages/views/widgets/message_action_sheet.dart';
import 'package:faunawatch/features/messages/views/widgets/message_tile.dart';
import 'package:faunawatch/features/messages/views/widgets/messages_filter_chips.dart';
import 'package:faunawatch/features/messages/views/widgets/messages_header.dart';
import 'package:faunawatch/features/messages/views/widgets/messages_search_bar.dart';

class ImmediateTestMessagesService implements MessagesService {
  @override
  Future<List<MessageThread>> fetchMessageThreads() async {
    return const [
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
  }

  @override
  Future<bool> markAsRead(String threadId) async => true;

  @override
  Future<bool> markAsUnread(String threadId) async => true;

  @override
  Future<bool> deleteThread(String threadId) async => true;

  @override
  Future<List<ChatMessage>> fetchChatMessages(String threadId) async =>
      const [];

  @override
  Future<ChatMessage> sendMessage({
    required String threadId,
    required String text,
    String? imageUrl,
  }) async {
    return ChatMessage(
      id: 'msg-mock',
      text: text,
      isUser: true,
      timestamp: 'Now',
    );
  }
}

void main() {
  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        messagesServiceProvider.overrideWithValue(
          ImmediateTestMessagesService(),
        ),
      ],
      child: const MaterialApp(home: MessagesView()),
    );
  }

  group('MessagesView', () {
    testWidgets(
      'renders header, search bar with where.webp, and filter chips',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(MessagesHeader), findsOneWidget);
        expect(find.text('Messages'), findsOneWidget);

        expect(find.byType(MessagesSearchBar), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName == AppAssets.whereIcon,
          ),
          findsOneWidget,
        );

        expect(find.byType(MessagesFilterChips), findsOneWidget);
        expect(find.text('All'), findsOneWidget);
        expect(find.text('Unread'), findsOneWidget);
      },
    );

    testWidgets(
      'renders message tiles with unread styling (yellow bar and background)',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(MessageTile), findsNWidgets(2));
        expect(find.text('Ranger Dave'), findsOneWidget);
        expect(find.text('Wildlife Rescue Team'), findsOneWidget);

        // Verify unread styling: row has yellow bar #FECE01 and background #FFFBE9
        final unreadTile = find.ancestor(
          of: find.text('Wildlife Rescue Team'),
          matching: find.byType(MessageTile),
        );
        expect(unreadTile, findsOneWidget);

        expect(
          find.descendant(
            of: unreadTile,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container &&
                  widget.color == AppColors.messagesUnreadBar,
            ),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('filters message list when Unread chip is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(MessageTile), findsNWidgets(2));

      await tester.tap(find.text('Unread'));
      await tester.pumpAndSettle();

      expect(find.byType(MessageTile), findsOneWidget);
      expect(find.text('Wildlife Rescue Team'), findsOneWidget);
      expect(find.text('Ranger Dave'), findsNothing);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.byType(MessageTile), findsNWidgets(2));
    });

    testWidgets('filters message list by search query input', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Dave');
      await tester.pumpAndSettle();

      expect(find.byType(MessageTile), findsOneWidget);
      expect(find.text('Ranger Dave'), findsOneWidget);
      expect(find.text('Wildlife Rescue Team'), findsNothing);
    });

    testWidgets('tapping a message tile opens ChatConversationView', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ranger Dave'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatConversationView), findsOneWidget);
    });

    testWidgets(
      'long pressing a message tile opens MessageActionSheet with mark as read/unread and delete options',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Long press unread thread
        await tester.longPress(find.text('Wildlife Rescue Team'));
        await tester.pumpAndSettle();

        expect(find.byType(MessageActionSheet), findsOneWidget);
        expect(find.text('Mark as read'), findsOneWidget);
        expect(find.text('Delete conversation'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        // Tap Mark as read
        await tester.tap(find.text('Mark as read'));
        await tester.pumpAndSettle();

        expect(find.byType(MessageActionSheet), findsNothing);

        // Long press again on now-read thread
        await tester.longPress(find.text('Wildlife Rescue Team'));
        await tester.pumpAndSettle();

        expect(find.text('Mark as unread'), findsOneWidget);

        // Tap Delete conversation
        await tester.tap(find.text('Delete conversation'));
        await tester.pumpAndSettle();

        expect(find.text('Wildlife Rescue Team'), findsNothing);
      },
    );
  });
}
