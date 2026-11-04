import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/messages/models/chat_message.dart';
import 'package:faunawatch/features/messages/models/chat_photo.dart';
import 'package:faunawatch/features/messages/models/chat_user.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';

abstract interface class MessagesService {
  static const pageSize = 50;
  Future<List<MessageThread>> fetchMessageThreads();
  Future<bool> markAsRead(String threadId, {String? throughMessageId});
  Future<bool> markAsUnread(String threadId);
  Future<bool> deleteThread(String threadId);
  Future<List<ChatMessage>> fetchChatMessages(
    String threadId, {
    ChatMessage? before,
  });
  Future<ChatMessage> sendMessage({
    required String threadId,
    required String text,
    ChatPhoto? photo,
  });
  Future<List<ChatUser>> searchUsers(String query);
  Future<MessageThread> openChat(ChatUser user);
  Future<String> photoUrl(String path);
  Stream<void> watchInbox();
  Stream<void> watchConversation(String threadId);
}

class SupabaseMessagesService implements MessagesService {
  SupabaseMessagesService(this._client);
  final SupabaseClient _client;
  static int _channelSequence = 0;
  String get _userId =>
      _client.auth.currentUser?.id ??
      (throw const AuthException('Sign in to use Chats.'));

  @override
  Future<List<MessageThread>> fetchMessageThreads() async {
    _userId;
    final rows = await _client.rpc('list_chat_threads');
    return Future.wait(
      (rows as List).map((raw) async {
        final row = Map<String, dynamic>.from(raw as Map);
        final path = row['avatar_path'] as String?;
        final asset = _preset(path);
        return MessageThread.fromJson(row).copyWith(
          avatarAsset: asset,
          avatarUrl: asset == null ? await _avatarUrl(path) : null,
        );
      }),
    );
  }

  String? _preset(String? path) => AppAssets.spotterAvatars
      .where(
        (asset) =>
            path == asset ||
            path == 'preset:${asset.split('/').last.split('.').first}',
      )
      .firstOrNull;
  Future<String?> _avatarUrl(String? path) async {
    if (path == null ||
        path.isEmpty ||
        path.startsWith('preset:') ||
        path.startsWith('assets/')) {
      return null;
    }
    try {
      return await _client.storage.from('avatars').createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _inboxAction(
    String threadId,
    String action, {
    String? messageId,
  }) async {
    _userId;
    return await _client.rpc(
          'set_chat_inbox_state',
          params: {
            'p_thread_id': threadId,
            'p_action': action,
            'p_read_message_id': messageId,
          },
        )
        as bool;
  }

  @override
  Future<bool> markAsRead(String threadId, {String? throughMessageId}) =>
      _inboxAction(threadId, 'read', messageId: throughMessageId);
  @override
  Future<bool> markAsUnread(String threadId) =>
      _inboxAction(threadId, 'unread');
  @override
  Future<bool> deleteThread(String threadId) => _inboxAction(threadId, 'hide');

  @override
  Future<List<ChatMessage>> fetchChatMessages(
    String threadId, {
    ChatMessage? before,
  }) async {
    final userId = _userId;
    var query = _client
        .from('chat_messages')
        .select()
        .eq('thread_id', threadId);
    if (before?.createdAt != null) {
      final date = before!.createdAt!.toUtc().toIso8601String();
      query = query.or(
        'created_at.lt.$date,and(created_at.eq.$date,id.lt.${before.id})',
      );
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(MessagesService.pageSize);
    final messages = await Future.wait(
      rows.map((row) => _message(row, userId)),
    );
    return messages.reversed.toList();
  }

  Future<ChatMessage> _message(Map<String, dynamic> row, String userId) async {
    final message = ChatMessage.fromJson(row, userId);
    if (message.imagePath == null) return message;
    try {
      final url = await photoUrl(message.imagePath!);
      return message.copyWith(imageUrl: url);
    } catch (_) {
      return message;
    } // Photo lookup failure must never cause a resend.
  }

  @override
  Future<String> photoUrl(String path) {
    _userId;
    return _client.storage.from('chat-images').createSignedUrl(path, 3600);
  }

  static String _uuid() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  Future<ChatMessage> sendMessage({
    required String threadId,
    required String text,
    ChatPhoto? photo,
  }) async {
    final userId = _userId;
    final body = text.trim();
    if (body.length > 4000 || (body.isEmpty && photo == null)) {
      throw const FormatException(
        'Enter a message of up to 4,000 characters or choose a photo.',
      );
    }
    if (photo != null &&
        (photo.bytes.isEmpty || photo.bytes.length > ChatPhoto.maxBytes)) {
      throw const FormatException('Choose a photo of 5 MB or less.');
    }
    final messageId = _uuid();
    final path = photo == null ? null : '$userId/$threadId/$messageId.webp';
    if (path != null) {
      await _client.storage
          .from('chat-images')
          .uploadBinary(
            path,
            photo!.bytes,
            fileOptions: const FileOptions(contentType: 'image/webp'),
          );
    }
    dynamic row;
    try {
      row = await _client.rpc(
        'send_chat_message',
        params: {
          'p_thread_id': threadId,
          'p_body': body,
          'p_message_id': messageId,
          'p_image_path': path,
        },
      );
    } catch (_) {
      // Recover a lost response after commit before reporting a send failure.
      try {
        row = await _client
            .from('chat_messages')
            .select()
            .eq('id', messageId)
            .maybeSingle();
      } catch (_) {
        /* Preserve the original failure. */
      }
      if (row == null) {
        if (path != null) {
          try {
            await _client.storage.from('chat-images').remove([path]);
          } catch (_) {
            /* RLS prevents deleting an already-shared attachment. */
          }
        }
        rethrow;
      }
    }
    return _message(Map<String, dynamic>.from(row as Map), userId);
  }

  @override
  Future<List<ChatUser>> searchUsers(String query) async {
    final userId = _userId;
    final term = query.trim();
    if (term.length < 2) return [];
    // Strip filter syntax; escape underscores so search cannot inject wildcards.
    final safe = term
        .replaceAll(RegExp(r'[(),."\\%*:]+'), '')
        .replaceAll('_', r'\_');
    if (safe.trim().length < 2) return [];
    final rows = await _client
        .from('profiles')
        .select('id, username, full_name, display_name, avatar_path')
        .neq('id', userId)
        .or(
          'username.ilike.%$safe%,full_name.ilike.%$safe%,display_name.ilike.%$safe%',
        )
        .order('id')
        .limit(20);
    return Future.wait(
      rows.map((row) async {
        final user = ChatUser.fromJson(row);
        final asset = _preset(user.avatarPath);
        return user.copyWith(
          avatarAsset: asset,
          avatarUrl: asset == null ? await _avatarUrl(user.avatarPath) : null,
        );
      }),
    );
  }

  @override
  Future<MessageThread> openChat(ChatUser user) async {
    _userId;
    final id =
        await _client.rpc('open_chat', params: {'p_other_user_id': user.id})
            as String;
    final asset = _preset(user.avatarPath);
    return MessageThread(
      id: id,
      senderName: user.name,
      lastMessage: '',
      timestamp: '',
      otherUserId: user.id,
      avatarAsset: asset,
      avatarUrl: asset == null ? await _avatarUrl(user.avatarPath) : null,
    );
  }

  Stream<void> _watch(String table, String column, String value) {
    late final StreamController<void> controller;
    RealtimeChannel? channel;
    controller = StreamController<void>(
      onListen: () {
        channel = _client
            .channel('chats:$table:$value:${_channelSequence++}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: table,
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: column,
                value: value,
              ),
              callback: (_) {
                if (!controller.isClosed) controller.add(null);
              },
            )
            .subscribe((status, error) {
              if (controller.isClosed) return;
              if (status == RealtimeSubscribeStatus.subscribed) {
                controller.add(null);
              }
              if (status == RealtimeSubscribeStatus.channelError ||
                  status == RealtimeSubscribeStatus.timedOut) {
                controller.addError(
                  StateError(
                    'Live updates disconnected. Refresh to try again.',
                  ),
                );
              }
            });
      },
      onCancel: () async {
        if (channel != null) await _client.removeChannel(channel!);
      },
    );
    return controller.stream;
  }

  @override
  Stream<void> watchInbox() => _watch('chat_participants', 'user_id', _userId);
  @override
  Stream<void> watchConversation(String threadId) {
    _userId;
    return _watch('chat_messages', 'thread_id', threadId);
  }
}

/// No client or subscriptions are retained while signed out (or restoring auth).
class SignedOutMessagesService implements MessagesService {
  const SignedOutMessagesService();
  Never _signIn() => throw const AuthException('Sign in to use Chats.');
  @override
  Future<List<MessageThread>> fetchMessageThreads() async => [];
  @override
  Future<List<ChatMessage>> fetchChatMessages(
    String threadId, {
    ChatMessage? before,
  }) async => _signIn();
  @override
  Future<bool> markAsRead(String threadId, {String? throughMessageId}) async =>
      _signIn();
  @override
  Future<bool> markAsUnread(String threadId) async => _signIn();
  @override
  Future<bool> deleteThread(String threadId) async => _signIn();
  @override
  Future<ChatMessage> sendMessage({
    required String threadId,
    required String text,
    ChatPhoto? photo,
  }) async => _signIn();
  @override
  Future<List<ChatUser>> searchUsers(String query) async => _signIn();
  @override
  Future<MessageThread> openChat(ChatUser user) async => _signIn();
  @override
  Future<String> photoUrl(String path) async => _signIn();
  @override
  Stream<void> watchInbox() => const Stream.empty();
  @override
  Stream<void> watchConversation(String threadId) => const Stream.empty();
}

final messagesServiceProvider = Provider<MessagesService>((ref) {
  if (ref.watch(currentUserIdProvider).valueOrNull == null) {
    return const SignedOutMessagesService();
  }
  return SupabaseMessagesService(ref.watch(supabaseClientProvider));
});
