import '../fake_messages_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/widgets/inset_centered_scroll.dart';
import 'package:faunawatch/features/messages/models/chat_message.dart';
import 'package:faunawatch/features/messages/models/chat_user.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';
import 'package:faunawatch/features/messages/services/messages_service.dart';
import 'package:faunawatch/features/messages/views/chat_conversation_view.dart';
import 'package:faunawatch/features/messages/views/messages_view.dart';
import 'package:faunawatch/features/messages/views/widgets/message_action_sheet.dart';
import 'package:faunawatch/features/messages/views/widgets/message_tile.dart';
import 'package:faunawatch/features/messages/views/widgets/messages_filter_chips.dart';
import 'package:faunawatch/features/messages/views/widgets/messages_header.dart';
import 'package:faunawatch/features/messages/views/widgets/messages_search_bar.dart';

class ImmediateTestMessagesService extends FakeMessagesService {
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
  Future<bool> markAsRead(String threadId, {String? throughMessageId}) async =>
      true;

  @override
  Future<bool> markAsUnread(String threadId) async => true;

  @override
  Future<bool> deleteThread(String threadId) async => true;

  @override
  Future<List<ChatMessage>> fetchChatMessages(
    String threadId, {
    ChatMessage? before,
  }) async => const [];

  @override
  Future<ChatMessage> sendMessage({
    required String threadId,
    required String text,
    ChatPhoto? photo,
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

  // Stands in for the floating nav bar the shell draws over the body.
  Widget buildWithInset(MessagesService service, double inset) {
    return ProviderScope(
      overrides: [messagesServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: EdgeInsets.only(bottom: inset)),
          child: child!,
        ),
        home: const MessagesView(),
      ),
    );
  }

  group('MessagesView nav bar inset', () {
    testWidgets('centres the empty state above the nav bar', (tester) async {
      const inset = 100.0;
      await tester.pumpWidget(buildWithInset(_EmptyInboxService(), inset));
      await tester.pumpAndSettle();

      expect(find.text('No conversations yet. Start a new chat.'), findsOne);
      final area = find.byType(InsetCenteredScroll);
      final visibleCentre =
          tester.getTopLeft(area).dy +
          (tester.getSize(area).height - inset) / 2;
      final content = find.descendant(of: area, matching: find.byType(Column));
      expect(tester.getCenter(content.first).dy, closeTo(visibleCentre, 1));
    });

    testWidgets('does not overflow on a short screen', (tester) async {
      tester.view.physicalSize = const Size(400, 380);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(buildWithInset(_EmptyInboxService(), 80));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('No conversations yet. Start a new chat.'), findsOne);
    });

    testWidgets('lets the last conversation scroll above the nav bar', (
      tester,
    ) async {
      const inset = 100.0;
      await tester.pumpWidget(buildWithInset(_ManyThreadsService(), inset));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      final bottomLimit = tester.getBottomLeft(find.byType(MessagesView)).dy;
      expect(
        tester.getBottomLeft(find.byType(MessageTile).last).dy,
        lessThanOrEqualTo(bottomLimit - inset),
      );
    });
  });

  group('MessagesView', () {
    testWidgets(
      'suggests matching people while typing and opens the selected chat',
      (tester) async {
        final service = _NewChatService();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [messagesServiceProvider.overrideWithValue(service)],
            child: const MaterialApp(home: MessagesView()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('New chat'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Bob');
        await tester.pump(const Duration(milliseconds: 299));
        expect(service.queries, isEmpty);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        expect(service.queries, ['Bob']);
        await tester.tap(find.widgetWithText(ListTile, 'Bob'));
        await tester.pumpAndSettle();
        expect(find.byType(ChatConversationView), findsOneWidget);
        expect(find.text('Bob'), findsOneWidget);
        expect(service.opened, 'user-b');
      },
    );
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

class _EmptyInboxService extends ImmediateTestMessagesService {
  @override
  Future<List<MessageThread>> fetchMessageThreads() async => const [];
}

class _ManyThreadsService extends ImmediateTestMessagesService {
  @override
  Future<List<MessageThread>> fetchMessageThreads() async => [
    for (var i = 0; i < 15; i++)
      MessageThread(
        id: 'thread-$i',
        senderName: 'Person $i',
        lastMessage: 'Hello $i',
        timestamp: '10:42 AM',
      ),
  ];
}

class _NewChatService extends ImmediateTestMessagesService {
  final queries = <String>[];
  String? opened;
  @override
  Future<List<ChatUser>> searchUsers(String query) async {
    queries.add(query);
    return const [ChatUser(id: 'user-b', name: 'Bob')];
  }

  @override
  Future<MessageThread> openChat(ChatUser user) async {
    opened = user.id;
    return MessageThread(
      id: 'new-private-thread',
      senderName: user.name,
      lastMessage: '',
      timestamp: '',
    );
  }
}
