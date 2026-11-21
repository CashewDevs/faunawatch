import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:faunawatch/features/feed/views/widgets/feed_post_card.dart';
import 'package:faunawatch/features/feed/views/widgets/for_you_feed.dart';
import 'package:faunawatch/features/feed/views/widgets/post_avatar.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_card.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_header.dart';
import 'package:faunawatch/features/messages/models/chat_message.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';
import 'package:faunawatch/features/messages/services/messages_service.dart';
import 'package:faunawatch/features/messages/views/chat_conversation_view.dart';
import 'package:faunawatch/features/messages/views/messages_view.dart';
import 'package:faunawatch/features/messages/views/widgets/chat_header.dart';
import 'package:faunawatch/features/messages/views/widgets/message_tile.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_header_card.dart';
import 'package:faunawatch/features/public_profile/services/public_profile_service.dart';
import 'package:faunawatch/features/public_profile/views/screens/public_gallery_post_viewer.dart';
import 'package:faunawatch/features/public_profile/views/screens/public_profile_screen.dart';
import 'package:faunawatch/features/public_profile/views/widgets/profile_link.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../feed/fake_feed_service.dart';
import '../messages/fake_messages_service.dart';
import 'fake_public_profile_service.dart';

class _Messages extends FakeMessagesService {
  static const thread = MessageThread(
    id: 'thread',
    senderName: 'Forest Ranger',
    lastMessage: 'Hello!',
    timestamp: '1m ago',
    otherUserId: 'other',
    isUnread: true,
  );
  int reads = 0;
  @override
  Future<List<MessageThread>> fetchMessageThreads() async => [thread];
  @override
  Future<List<ChatMessage>> fetchChatMessages(
    String threadId, {
    ChatMessage? before,
  }) async => [];
  @override
  Future<bool> markAsRead(String threadId, {String? throughMessageId}) async {
    ++reads;
    return true;
  }

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
    public = FakePublicProfileService()..posts = [publicPost('a')];
    feed = FakeFeedService(posts: public.posts);
    messages = _Messages();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
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
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets(
      'public profile reuses identity and gallery design in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        await pump(
          tester,
          const PublicProfileScreen(userId: 'other'),
          dark: dark,
        );
        expect(find.byType(ProfileHeaderCard), findsOneWidget);
        expect(find.byType(GalleryHeader), findsOneWidget);
        expect(find.byType(GalleryCard), findsOneWidget);
        expect(find.text('Public Gallery'), findsOneWidget);
        expect(find.text('Forest Ranger'), findsNWidgets(2));
        expect(find.byTooltip('Profile & preferences'), findsNothing);
        expect(find.text('Edit Profile'), findsNothing);
        expect(find.text('Pending'), findsNothing);
        final title = tester.widget<Text>(find.text('Public Gallery'));
        expect(
          title.style!.fontFamily,
          GoogleFonts.dmSans(fontWeight: FontWeight.w800).fontFamily,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final avatar in [false, true]) {
    testWidgets(
      'own feed ${avatar ? 'avatar' : 'name'} selects the existing Profile tab',
      (tester) async {
        feed.posts = [publicPost('own', authorId: 'viewer')];
        await pump(
          tester,
          const Scaffold(
            body: ForYouFeed(backgroundColor: Colors.white, isDark: false),
          ),
        );
        final context = tester.element(find.byType(ForYouFeed));
        final container = ProviderScope.containerOf(context, listen: false);
        expect(container.read(shellViewModelProvider), ShellDestination.feed);

        await tester.tap(
          avatar
              ? find.byType(PostAvatar)
              : find.textContaining('Forest Ranger', findRichText: true),
        );
        await tester.pumpAndSettle();

        expect(
          container.read(shellViewModelProvider),
          ShellDestination.profile,
        );
        expect(find.byType(PublicProfileScreen), findsNothing);
        expect(Navigator.of(context).canPop(), isFalse);
        expect(public.profileRequests, isEmpty);
        expect(public.postRequests, isEmpty);
      },
    );

    testWidgets(
      'feed ${avatar ? 'avatar' : 'name'} opens the author and Back restores its card',
      (tester) async {
        final post = public.posts.single;
        await pump(
          tester,
          Scaffold(
            body: FeedPostCard(post: post, backgroundColor: Colors.white),
          ),
        );
        final caption = find.textContaining(
          'Forest Ranger',
          findRichText: true,
        );
        await tester.tap(avatar ? find.byType(PostAvatar) : caption);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PublicProfileScreen>(find.byType(PublicProfileScreen))
              .userId,
          'other',
        );
        expect(public.profileRequests, ['other']);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(FeedPostCard), findsOneWidget);
        expect(feed.pageRequests, isEmpty);
      },
    );

    testWidgets(
      'inbox ${avatar ? 'avatar' : 'name'} opens a profile without reading or opening the chat',
      (tester) async {
        await pump(tester, const MessagesView());
        final link = find.descendant(
          of: find.byType(MessageTile),
          matching: find.byType(ProfileLink),
        );
        await tester.tap(avatar ? link.first : link.last);
        await tester.pumpAndSettle();
        expect(find.byType(PublicProfileScreen), findsOneWidget);
        expect(find.byType(ChatConversationView), findsNothing);
        expect(messages.reads, 0);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hello!'));
        await tester.pumpAndSettle();
        expect(find.byType(ChatConversationView), findsOneWidget);
      },
    );

    testWidgets(
      'chat header ${avatar ? 'avatar' : 'name'} opens the other profile and returns to the conversation',
      (tester) async {
        await pump(
          tester,
          const ChatConversationView(thread: _Messages.thread),
        );
        await tester.enterText(find.byType(TextField).last, 'Saved chat draft');
        final links = find.descendant(
          of: find.byType(ChatHeader),
          matching: find.byType(ProfileLink),
        );
        await tester.tap(avatar ? links.first : links.last);
        await tester.pumpAndSettle();
        expect(find.byType(PublicProfileScreen), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(ChatConversationView), findsOneWidget);
        expect(find.text('Forest Ranger'), findsOneWidget);
        expect(find.text('Saved chat draft'), findsOneWidget);
      },
    );
  }

  testWidgets('opening an author preserves the selected For You page', (
    tester,
  ) async {
    feed.posts = [publicPost('first'), publicPost('second')];
    await pump(
      tester,
      const Scaffold(
        body: ForYouFeed(backgroundColor: Colors.white, isDark: false),
      ),
    );
    await tester.drag(find.byType(PageView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('second')),
        matching: find.byType(PostAvatar),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PublicProfileScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
  });

  testWidgets(
    'public gallery opens its own posts with local engagement and preserves grid position',
    (tester) async {
      public.posts = List.generate(12, (i) => publicPost('p$i'));
      final first = public.posts;
      public.onPosts = (_, before, _) async => before == null ? first : [];
      feed.posts = first;
      await pump(tester, const PublicProfileScreen(userId: 'other'));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('p11')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final before = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      await tester.tap(find.byKey(const ValueKey('p11')));
      await tester.pumpAndSettle();
      expect(find.byType(PublicGalleryPostViewer), findsOneWidget);
      expect(
        tester
            .widget<FeedPostCard>(find.byType(FeedPostCard).last)
            .post
            .authorId,
        'other',
      );
      await tester.tap(find.bySemanticsLabel('Like, 0').last);
      await tester.pumpAndSettle();
      expect(feed.likes, ['p11']);
      expect(feed.pageRequests, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        closeTo(before, 1),
      );
    },
  );

  testWidgets(
    'missing profiles and empty public galleries show distinct states',
    (tester) async {
      public.profile = null;
      await pump(tester, const PublicProfileScreen(userId: 'gone'));
      expect(find.text('This profile is no longer available.'), findsOneWidget);
      expect(public.postRequests, isEmpty);
    },
  );

  testWidgets('gallery failures keep public identity visible and can retry', (
    tester,
  ) async {
    public.postsError = StateError('offline');
    await pump(tester, const PublicProfileScreen(userId: 'other'));
    expect(find.text('Forest Ranger'), findsNWidgets(2));
    expect(find.text('Could not load this gallery.'), findsOneWidget);
    public.postsError = null;
    public.posts = [];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No public posts yet.'), findsOneWidget);
  });

  testWidgets('public profile fits a narrow viewport with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    public.posts = [];
    await pump(tester, const PublicProfileScreen(userId: 'other'), scale: 2);
    expect(tester.takeException(), isNull);
  });
}
