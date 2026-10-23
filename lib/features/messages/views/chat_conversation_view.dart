import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';
import 'package:faunawatch/features/messages/viewmodels/chat_conversation_viewmodel.dart';
import 'package:faunawatch/features/messages/views/widgets/chat_bubble.dart';
import 'package:faunawatch/features/messages/views/widgets/chat_header.dart';
import 'package:faunawatch/features/messages/views/widgets/chat_input_bar.dart';

/// Full-screen chat conversation view.
///
/// Hides the main navigation bar when opened.
/// Features:
/// - Header in [#FFFBE9] with `left.webp` back button, gray circular pfp, and DM Sans extrabold username
/// - Speech bubbles with horizontal gradients:
///   - User: 0% [#A4DDFF] to 100% [#DCF2FF]
///   - Other user: 0% [#D5D5D5] to 100% [#E8E8E8]
/// - Bottom input bar with `addIM.webp`, "Type something" placeholder, and `sendM.webp` send button
class ChatConversationView extends ConsumerWidget {
  const ChatConversationView({super.key, required this.thread});

  final MessageThread thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatConversationViewModelProvider(thread.id));
    final viewModel = ref.read(
      chatConversationViewModelProvider(thread.id).notifier,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (#FFFBE9, left.webp, pfp, DM Sans extrabold username)
          ChatHeader(
            username: thread.senderName,
            avatarAsset: thread.avatarAsset,
            onBack: () => Navigator.of(context).pop(),
          ),

          // Message bubble list
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      // The 4th item (index 3) can be rendered without a tail as shown in mockup
                      final showTail = index != 3;
                      return ChatBubble(message: message, showTail: showTail);
                    },
                  ),
          ),

          // Typing input bar (addIM.webp, "Type something", sendM.webp)
          ChatInputBar(onSend: (text) => viewModel.sendMessage(text)),
        ],
      ),
    );
  }
}
