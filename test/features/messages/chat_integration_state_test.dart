import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/messages/models/chat_user.dart';
import 'package:faunawatch/features/messages/services/messages_service.dart';
import 'package:faunawatch/features/messages/services/chat_photo_service.dart';
import 'package:faunawatch/features/messages/viewmodels/chat_conversation_viewmodel.dart';
import 'package:faunawatch/features/messages/viewmodels/messages_viewmodel.dart';
import 'package:faunawatch/features/messages/viewmodels/new_chat_viewmodel.dart';
import 'fake_messages_service.dart';

class _Service extends FakeMessagesService {
  final changes = StreamController<void>.broadcast();
  final inbox = StreamController<void>.broadcast();
  List<ChatMessage> messages = [];
  List<ChatMessage> older = [];
  bool fail = false;
  int sends = 0;
  ChatPhoto? sentPhoto;
  final reads = <String?>[];
  Completer<ChatMessage>? pendingSend;
  Completer<List<ChatMessage>>? pendingLoad;
  final searches = <String, Completer<List<ChatUser>>>{};
  @override
  Stream<void> watchConversation(String id) => changes.stream;
  @override
  Stream<void> watchInbox() => inbox.stream;
  @override
  Future<List<MessageThread>> fetchMessageThreads() async {
    if (fail) throw StateError('test failure');
    return const [
      MessageThread(
        id: 't',
        senderName: 'Bob',
        lastMessage: '',
        timestamp: '',
        isUnread: true,
      ),
    ];
  }

  @override
  Future<List<ChatMessage>> fetchChatMessages(
    String id, {
    ChatMessage? before,
  }) async {
    if (pendingLoad != null) return pendingLoad!.future;
    if (fail) throw StateError('test failure');
    return before == null ? messages : older;
  }

  @override
  Future<bool> markAsRead(String id, {String? throughMessageId}) async {
    reads.add(throughMessageId);
    return !fail;
  }

  @override
  Future<bool> markAsUnread(String id) async => !fail;
  @override
  Future<bool> deleteThread(String id) async => !fail;
  @override
  Future<String> photoUrl(String path) async {
    if (fail) throw StateError('test photo failure');
    return 'https://chat-tests.invalid/renewed-photo';
  }

  @override
  Future<ChatMessage> sendMessage({
    required String threadId,
    required String text,
    ChatPhoto? photo,
  }) async {
    sends++;
    sentPhoto = photo;
    if (fail) throw StateError('test failure');
    return pendingSend?.future ?? Future.value(_message(2));
  }

  @override
  Future<List<ChatUser>> searchUsers(String query) =>
      (searches[query] = Completer<List<ChatUser>>()).future;
  @override
  Future<MessageThread> openChat(ChatUser user) async {
    if (fail) throw StateError('test failure');
    return super.openChat(user);
  }

  Future<void> close() async {
    await changes.close();
    await inbox.close();
  }
}

class _Photos implements ChatPhotoService {
  ChatPhoto? photo = ChatPhoto(Uint8List.fromList([1, 2, 3]));
  bool fail = false;
  @override
  Future<ChatPhoto?> pickPhoto() async {
    if (fail) throw const FormatException('Choose a photo of 5 MB or less.');
    return photo;
  }
}

ChatMessage _message(int n) => ChatMessage(
  id: 'm-$n',
  text: 'Message $n',
  isUser: n == 2,
  timestamp: '',
  createdAt: DateTime.utc(2026, 11, 4, 12, n),
);

void main() {
  late _Service service;
  late _Photos photos;
  late ProviderContainer container;
  final provider = chatConversationViewModelProvider('t');
  setUp(() {
    service = _Service()..messages = [_message(1)];
    photos = _Photos();
    container = ProviderContainer(
      overrides: [
        messagesServiceProvider.overrideWithValue(service),
        chatPhotoServiceProvider.overrideWithValue(photos),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await service.close();
  });
  Future<ChatConversationViewModel> conversation() async {
    container.listen(provider, (_, _) {});
    await pumpEventQueue();
    return container.read(provider.notifier);
  }

  test(
    'renews expired private photo links without resending a message',
    () async {
      const photoMessage = ChatMessage(
        id: 'photo',
        text: '',
        isUser: false,
        timestamp: '',
        imagePath: 'user-b/t/photo.webp',
      );
      service.messages = [photoMessage];
      final vm = await conversation();
      service.fail = true;
      await vm.reloadPhoto(photoMessage);
      expect(
        container.read(provider).error,
        contains('Could not load this photo'),
      );
      service.fail = false;
      await vm.reloadPhoto(photoMessage);
      expect(
        container.read(provider).messages.single.imageUrl,
        contains('renewed-photo'),
      );
      expect(service.sends, 0);
    },
  );

  test(
    'refresh clears previously loaded history when server access disappears',
    () async {
      final vm = await conversation();
      service.messages = [];
      await vm.refresh();
      expect(container.read(provider).messages, isEmpty);
      expect(container.read(provider).hasMore, isFalse);
    },
  );

  test(
    'live updates merge with sent response without duplicating bubbles',
    () async {
      final vm = await conversation();
      await vm.sendMessage('Hello');
      service.messages = [_message(1), _message(2)];
      service.changes.add(null);
      await pumpEventQueue();
      expect(container.read(provider).messages.map((m) => m.id), [
        'm-1',
        'm-2',
      ]);
      expect(service.reads.last, 'm-2');
    },
  );
  test(
    'background updates are not marked read until the chat resumes',
    () async {
      final vm = await conversation();
      service.reads.clear();
      vm.setActive(false);
      service.messages = [_message(1), _message(2)];
      service.changes.add(null);
      await pumpEventQueue();
      expect(service.reads, isEmpty);
      vm.setActive(true);
      await pumpEventQueue();
      expect(service.reads, ['m-2']);
    },
  );
  test('failed send retains photo and retry clears it after success', () async {
    final vm = await conversation();
    await vm.pickPhoto();
    service.fail = true;
    expect(await vm.sendMessage('caption'), isFalse);
    expect(container.read(provider).photo, same(photos.photo));
    expect(container.read(provider).error, contains('not sent'));
    service.fail = false;
    expect(await vm.sendMessage('caption'), isTrue);
    expect(service.sentPhoto, same(photos.photo));
    expect(container.read(provider).photo, isNull);
    expect(container.read(provider).error, isNull);
  });
  test(
    'allows photo-only sends and blocks repeated taps while sending',
    () async {
      final vm = await conversation();
      expect(await vm.sendMessage(' '), isFalse);
      await vm.pickPhoto();
      service.pendingSend = Completer<ChatMessage>();
      final first = vm.sendMessage('');
      expect(container.read(provider).isSending, isTrue);
      expect(await vm.sendMessage(''), isFalse);
      expect(service.sends, 1);
      service.pendingSend!.complete(_message(2));
      expect(await first, isTrue);
    },
  );
  test(
    'photo errors are safe and cancellation preserves an existing attachment',
    () async {
      final vm = await conversation();
      await vm.pickPhoto();
      final selected = container.read(provider).photo;
      photos.photo = null;
      await vm.pickPhoto();
      expect(container.read(provider).photo, same(selected));
      photos.fail = true;
      await vm.pickPhoto();
      expect(container.read(provider).error, contains('5 MB'));
      vm.removePhoto();
      expect(container.read(provider).photo, isNull);
    },
  );
  test('initial failure is visible and refresh recovers', () async {
    service.fail = true;
    final vm = await conversation();
    expect(container.read(provider).isLoading, isFalse);
    expect(container.read(provider).error, isNotNull);
    service.fail = false;
    await vm.refresh();
    expect(container.read(provider).messages.length, 1);
    expect(container.read(provider).error, isNull);
  });
  test('loads older pages without losing the current messages', () async {
    service.messages = List.generate(50, (n) => _message(n + 10));
    service.older = [_message(1)];
    final vm = await conversation();
    expect(container.read(provider).hasMore, isTrue);
    await vm.loadOlder();
    expect(container.read(provider).messages.length, 51);
    expect(container.read(provider).messages.first.id, 'm-1');
    expect(container.read(provider).hasMore, isFalse);
  });
  test(
    'account service replacement discards old results and private history',
    () async {
      final vm = await conversation();
      service.pendingLoad = Completer<List<ChatMessage>>();
      final oldRefresh = vm.refresh();
      final next = _Service()..messages = [];
      addTearDown(next.close);
      container.updateOverrides([
        messagesServiceProvider.overrideWithValue(next),
        chatPhotoServiceProvider.overrideWithValue(photos),
      ]);
      await pumpEventQueue();
      service.pendingLoad!.complete([_message(3)]);
      await oldRefresh;
      await pumpEventQueue();
      expect(container.read(provider).messages, isEmpty);
      expect(service.changes.hasListener, isFalse);
    },
  );
  test(
    'disposal cancels live subscription and ignores pending responses',
    () async {
      service.pendingLoad = Completer<List<ChatMessage>>();
      final sub = container.listen(provider, (_, _) {});
      await pumpEventQueue();
      expect(service.changes.hasListener, isTrue);
      sub.close();
      await pumpEventQueue();
      expect(service.changes.hasListener, isFalse);
      service.pendingLoad!.complete([_message(1)]);
      await pumpEventQueue();
    },
  );
  test(
    'failed inbox actions do not remove conversations or change unread state',
    () async {
      container.read(messagesViewModelProvider);
      await pumpEventQueue();
      final vm = container.read(messagesViewModelProvider.notifier);
      service.fail = true;
      await vm.markThreadRead('t');
      await vm.deleteConversation('t');
      final state = container.read(messagesViewModelProvider);
      expect(state.threads.single.isUnread, isTrue);
      expect(state.error, isNotNull);
    },
  );
  test(
    'new search ignores older responses and rejects too-short queries',
    () async {
      container.listen(newChatViewModelProvider, (_, _) {});
      final vm = container.read(newChatViewModelProvider.notifier);
      await vm.search('a');
      expect(service.searches, isEmpty);
      final first = vm.search('Alice');
      final second = vm.search('Bob');
      service.searches['Bob']!.complete([const ChatUser(id: 'b', name: 'Bob')]);
      await second;
      service.searches['Alice']!.complete([
        const ChatUser(id: 'a', name: 'Alice'),
      ]);
      await first;
      expect(container.read(newChatViewModelProvider).users.single.name, 'Bob');
    },
  );
  testWidgets('typing waits briefly and only requests the latest name', (
    tester,
  ) async {
    container.listen(newChatViewModelProvider, (_, _) {});
    final vm = container.read(newChatViewModelProvider.notifier);
    vm.onQueryChanged('Bo');
    await tester.pump(const Duration(milliseconds: 200));
    vm.onQueryChanged('Bob');
    await tester.pump(const Duration(milliseconds: 299));
    expect(service.searches, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(service.searches.keys, ['Bob']);
    service.searches['Bob']!.complete([const ChatUser(id: 'b', name: 'Bob')]);
    await tester.pump();
    expect(container.read(newChatViewModelProvider).users.single.name, 'Bob');
  });
  testWidgets(
    'editing or clearing rejects the previous name response immediately',
    (tester) async {
      container.listen(newChatViewModelProvider, (_, _) {});
      final vm = container.read(newChatViewModelProvider.notifier);
      final old = vm.search('Alice');
      vm.onQueryChanged('Bob');
      service.searches['Alice']!.complete([
        const ChatUser(id: 'a', name: 'Alice'),
      ]);
      await tester.pump();
      await old;
      expect(container.read(newChatViewModelProvider).users, isEmpty);
      vm.onQueryChanged('');
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.searches.keys, ['Alice']);
      expect(container.read(newChatViewModelProvider).isSearching, isFalse);
      expect(container.read(newChatViewModelProvider).error, isNull);
    },
  );
  testWidgets('submitting immediately cancels the pending suggestion request', (
    tester,
  ) async {
    container.listen(newChatViewModelProvider, (_, _) {});
    final vm = container.read(newChatViewModelProvider.notifier);
    vm.onQueryChanged('Bob');
    final submitted = vm.search('Bob');
    final response = service.searches['Bob']!;
    response.complete([const ChatUser(id: 'b', name: 'Bob')]);
    await tester.pump();
    await submitted;
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.searches['Bob'], same(response));
    expect(container.read(newChatViewModelProvider).users.single.name, 'Bob');
  });
  testWidgets('leaving user search cancels a pending suggestion timer', (
    tester,
  ) async {
    final subscription = container.listen(newChatViewModelProvider, (_, _) {});
    container.read(newChatViewModelProvider.notifier).onQueryChanged('Bob');
    subscription.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.searches, isEmpty);
  });
  test('opening a conversation reports failure and can be retried', () async {
    container.listen(newChatViewModelProvider, (_, _) {});
    final vm = container.read(newChatViewModelProvider.notifier);
    service.fail = true;
    expect(await vm.open(const ChatUser(id: 'b', name: 'Bob')), isNull);
    expect(container.read(newChatViewModelProvider).error, isNotNull);
    service.fail = false;
    expect(
      (await vm.open(const ChatUser(id: 'b', name: 'Bob')))!.id,
      'new-thread',
    );
  });
}
