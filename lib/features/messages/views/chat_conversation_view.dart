import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';
import 'package:faunawatch/features/messages/viewmodels/chat_conversation_viewmodel.dart';
import 'package:faunawatch/features/messages/views/widgets/chat_bubble.dart';
import 'package:faunawatch/features/messages/views/widgets/chat_header.dart';
import 'package:faunawatch/features/messages/views/widgets/chat_input_bar.dart';

class ChatConversationView extends ConsumerStatefulWidget {
  const ChatConversationView({super.key, required this.thread});
  final MessageThread thread;
  @override
  ConsumerState<ChatConversationView> createState() =>
      _ChatConversationViewState();
}

class _ChatConversationViewState extends ConsumerState<ChatConversationView> {
  late final AppLifecycleListener _lifecycle;
  bool _resumed = true;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _resumed = state == AppLifecycleState.resumed;
        ref
            .read(chatConversationViewModelProvider(widget.thread.id).notifier)
            .setActive(_resumed);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thread = widget.thread;
    final state = ref.watch(chatConversationViewModelProvider(thread.id));
    final vm = ref.read(chatConversationViewModelProvider(thread.id).notifier);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChatHeader(
            username: thread.senderName,
            avatarAsset: thread.avatarAsset,
            avatarUrl: thread.avatarUrl,
            onBack: () => Navigator.of(context).pop(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (state.isSending || state.isPickingPhoto)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                tooltip: 'Refresh chat',
                onPressed: vm.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                state.error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.messages.isEmpty
                ? const Center(child: Text('Start the conversation.'))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: state.messages.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.messages.length) {
                        return Center(
                          child: TextButton(
                            onPressed: state.isLoadingMore
                                ? null
                                : vm.loadOlder,
                            child: Text(
                              state.isLoadingMore
                                  ? 'Loading…'
                                  : 'Load older messages',
                            ),
                          ),
                        );
                      }
                      final message =
                          state.messages[state.messages.length - 1 - index];
                      return ChatBubble(
                        message: message,
                        onReloadPhoto: () => vm.reloadPhoto(message),
                      );
                    },
                  ),
          ),
          if (state.photo != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Image.memory(
                    state.photo!.bytes,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.image),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Photo ready to send')),
                  IconButton(
                    tooltip: 'Remove photo',
                    onPressed: state.isSending ? null : vm.removePhoto,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ChatInputBar(
            key: ValueKey(vm.sessionRevision),
            onSend: vm.sendMessage,
            onAddImage: vm.pickPhoto,
            isBusy: state.isLoading || state.isSending || state.isPickingPhoto,
            hasPhoto: state.photo != null,
          ),
        ],
      ),
    );
  }
}
