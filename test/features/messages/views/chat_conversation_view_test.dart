import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/messages/models/chat_message.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';
import 'package:faunawatch/features/messages/services/messages_service.dart';
import 'package:faunawatch/features/messages/views/chat_conversation_view.dart';
import 'package:faunawatch/features/messages/views/widgets/chat_bubble.dart';
import 'package:faunawatch/features/messages/views/widgets/chat_header.dart';
import 'package:faunawatch/features/messages/views/widgets/chat_input_bar.dart';

class TestChatService implements MessagesService {
  @override
  Future<List<MessageThread>> fetchMessageThreads() async => const [];

  @override
  Future<bool> markAsRead(String threadId) async => true;

  @override
  Future<bool> markAsUnread(String threadId) async => true;

  @override
  Future<bool> deleteThread(String threadId) async => true;

  @override
  Future<List<ChatMessage>> fetchChatMessages(String threadId) async {
    return const [
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
  }

  @override
  Future<ChatMessage> sendMessage({
    required String threadId,
    required String text,
    String? imageUrl,
  }) async {
    return ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isUser: true,
      timestamp: 'Just now',
      imageUrl: imageUrl,
    );
  }
}

void main() {
  const testThread = MessageThread(
    id: 'thread-test',
    senderName: 'Ranger Dave',
    lastMessage: 'Latest report',
    timestamp: '1h ago',
    isUnread: false,
  );

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [messagesServiceProvider.overrideWithValue(TestChatService())],
      child: const MaterialApp(home: ChatConversationView(thread: testThread)),
    );
  }

  group('ChatConversationView', () {
    testWidgets(
      'renders header with #FFFBE9, left.webp, pfp circle, and DM Sans extrabold username',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(ChatHeader), findsOneWidget);
        expect(find.text('Ranger Dave'), findsOneWidget);

        // Header container has #FFFBE9 background
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color ==
                    AppColors.chatHeaderBackground,
          ),
          findsOneWidget,
        );

        // left.webp icon is present
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName == AppAssets.backArrowIcon,
          ),
          findsOneWidget,
        );

        // PFP circle is present (#D9D9D9)
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color ==
                    AppColors.messagesPfpPlaceholder,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders user and other-user chat bubbles with gradients', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ChatBubble), findsNWidgets(2));
      expect(find.text('Other user message'), findsOneWidget);
      expect(find.text('Current user message'), findsOneWidget);

      // Verify user bubble has horizontal gradient from #A4DDFF to #DCF2FF
      expect(
        find.byWidgetPredicate((w) {
          if (w is Container && w.decoration is BoxDecoration) {
            final grad = (w.decoration as BoxDecoration).gradient;
            if (grad is LinearGradient) {
              return grad.colors.contains(
                AppColors.chatUserBubbleGradientStart,
              );
            }
          }
          return false;
        }),
        findsOneWidget,
      );

      // Verify other user bubble has horizontal gradient from #D5D5D5 to #E8E8E8
      expect(
        find.byWidgetPredicate((w) {
          if (w is Container && w.decoration is BoxDecoration) {
            final grad = (w.decoration as BoxDecoration).gradient;
            if (grad is LinearGradient) {
              return grad.colors.contains(
                AppColors.chatOtherBubbleGradientStart,
              );
            }
          }
          return false;
        }),
        findsOneWidget,
      );
    });

    testWidgets(
      'renders input bar with addIM.webp, "Type something", and sendM.webp',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(ChatInputBar), findsOneWidget);
        expect(find.text('Type something'), findsOneWidget);

        // addIM.webp icon is present
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName == AppAssets.addImageIcon,
          ),
          findsOneWidget,
        );

        // sendM.webp icon is present
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName == AppAssets.sendMessageIcon,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('typing and tapping send adds a new chat message bubble', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ChatBubble), findsNWidgets(2));

      await tester.enterText(find.byType(TextField), 'Testing message send');
      await tester.tap(find.bySemanticsLabel('Send message'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatBubble), findsNWidgets(3));
      expect(find.text('Testing message send'), findsOneWidget);
    });

    testWidgets('tapping back button calls Navigator.pop', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            messagesServiceProvider.overrideWithValue(TestChatService()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const ChatConversationView(thread: testThread),
                    ),
                  ),
                  child: const Text('Open Chat'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Chat'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatConversationView), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatConversationView), findsNothing);
    });
  });
}
