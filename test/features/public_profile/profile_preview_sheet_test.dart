import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:faunawatch/features/feed/views/widgets/for_you_feed.dart';
import 'package:faunawatch/features/feed/views/widgets/post_avatar.dart';
import 'package:faunawatch/features/messages/models/chat_message.dart';
import 'package:faunawatch/features/messages/models/chat_user.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';
import 'package:faunawatch/features/messages/services/messages_service.dart';
import 'package:faunawatch/features/messages/views/chat_conversation_view.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_header_card.dart';
import 'package:faunawatch/features/public_profile/services/public_profile_service.dart';
import 'package:faunawatch/features/public_profile/views/screens/public_profile_screen.dart';
import 'package:faunawatch/features/public_profile/views/widgets/profile_preview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../feed/fake_feed_service.dart';
import '../messages/fake_messages_service.dart';
import 'fake_public_profile_service.dart';

class _Messages extends FakeMessagesService {
  String? openedUserId;
  Object? openError;

  @override
  Future<List<MessageThread>> fetchMessageThreads() async => [];
  @override
  Future<MessageThread> openChat(ChatUser user) async {
    if (openError != null) throw openError!;
    openedUserId = user.id;
    return MessageThread(
      id: 'thread-${user.id}',
      senderName: user.name,
      lastMessage: '',
      timestamp: '',
      otherUserId: user.id,
      avatarAsset: user.avatarAsset,
    );
  }

  @override
  Future<List<ChatMessage>> fetchChatMessages(
    String threadId, {
    ChatMessage? before,
  }) async => [];
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
  }) async => throw StateError('No send expected');
}

void main() {
  late FakePublicProfileService public;
  late FakeFeedService feed;
  late _Messages messages;
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    public = FakePublicProfileService()
      ..profile = const ProfileData(
        username: 'Forest Ranger',
        bio: 'Counting hornbills every weekend',
        presetAvatar: AppAssets.avatarPanda,
        bannerAsset: AppAssets.bannerDay,
      );
    feed = FakeFeedService(posts: [publicPost('a')]);
    messages = _Messages();
  });

  Future<void> pumpFeed(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => Stream.value('viewer')),
          publicProfileServiceProvider.overrideWithValue(public),
          feedServiceProvider.overrideWithValue(feed),
          messagesServiceProvider.overrideWithValue(messages),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: ForYouFeed(backgroundColor: Colors.white, isDark: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPreview(WidgetTester tester) async {
    await tester.tap(find.byType(PostAvatar));
    await tester.pumpAndSettle();
  }

  final fullProfileButton = find.byKey(
    const ValueKey('profile_preview_full_profile'),
  );

  for (final avatar in [true, false]) {
    testWidgets(
      'feed ${avatar ? 'avatar' : 'author name'} opens the profile preview without loading posts',
      (tester) async {
        await pumpFeed(tester);
        await tester.tap(
          avatar
              ? find.byType(PostAvatar)
              : find.textContaining('Forest Ranger', findRichText: true),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ProfilePreviewSheet), findsOneWidget);
        expect(find.byType(PublicProfileScreen), findsNothing);
        expect(
          find.descendant(
            of: find.byType(ProfilePreviewSheet),
            matching: find.byType(ProfileHeaderCard),
          ),
          findsOneWidget,
        );
        expect(find.text('Counting hornbills every weekend'), findsOneWidget);
        expect(find.text('Message'), findsOneWidget);
        expect(fullProfileButton, findsOneWidget);
        expect(public.profileRequests, ['other']);
        expect(public.postRequests, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'View full profile closes the preview, and Back returns to the post',
    (tester) async {
      await pumpFeed(tester);
      await openPreview(tester);

      await tester.tap(fullProfileButton);
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePreviewSheet), findsNothing);
      expect(
        tester
            .widget<PublicProfileScreen>(find.byType(PublicProfileScreen))
            .userId,
        'other',
      );
      expect(public.postRequests.single.userId, 'other');

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(PublicProfileScreen), findsNothing);
      expect(find.byType(ProfilePreviewSheet), findsNothing);
      expect(find.byType(ForYouFeed), findsOneWidget);
    },
  );

  testWidgets('Message closes the preview and opens the private chat', (
    tester,
  ) async {
    await pumpFeed(tester);
    await openPreview(tester);

    await tester.tap(find.text('Message'));
    await tester.pumpAndSettle();
    expect(messages.openedUserId, 'other');
    expect(find.byType(ProfilePreviewSheet), findsNothing);
    expect(
      tester
          .widget<ChatConversationView>(find.byType(ChatConversationView))
          .thread
          .id,
      'thread-other',
    );
  });

  testWidgets('a chat that cannot start shows its error inside the preview', (
    tester,
  ) async {
    messages.openError = StateError('offline');
    await pumpFeed(tester);
    await openPreview(tester);

    await tester.tap(find.text('Message'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePreviewSheet), findsOneWidget);
    expect(find.byType(ChatConversationView), findsNothing);
    expect(
      find.text('Could not start this chat. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('a profile that fails to load can be retried', (tester) async {
    public.profileError = StateError('offline');
    await pumpFeed(tester);
    await openPreview(tester);
    expect(find.text('Could not load this profile.'), findsOneWidget);
    expect(fullProfileButton, findsNothing);

    public.profileError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Forest Ranger'), findsWidgets);
    expect(fullProfileButton, findsOneWidget);
  });

  testWidgets('a deleted profile says so and offers no buttons', (
    tester,
  ) async {
    public.profile = null;
    await pumpFeed(tester);
    await openPreview(tester);
    expect(find.text('This profile is no longer available.'), findsOneWidget);
    expect(find.text('Message'), findsNothing);
    expect(fullProfileButton, findsNothing);
  });

  testWidgets('the preview fits a narrow dark screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpFeed(tester, dark: true, scale: 2);
    await openPreview(tester);
    expect(find.byType(ProfilePreviewSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
