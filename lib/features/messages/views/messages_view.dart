import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/features/messages/viewmodels/messages_viewmodel.dart';
import 'package:faunawatch/features/messages/views/chat_conversation_view.dart';
import 'package:faunawatch/features/messages/views/new_chat_view.dart';
import 'package:faunawatch/features/messages/views/widgets/message_action_sheet.dart';
import 'package:faunawatch/features/messages/views/widgets/message_tile.dart';
import 'package:faunawatch/features/messages/views/widgets/messages_filter_chips.dart';
import 'package:faunawatch/features/messages/views/widgets/messages_header.dart';
import 'package:faunawatch/features/messages/views/widgets/messages_search_bar.dart';

/// Screen displaying the conversation message threads with search and filters.
///
/// Implements the visual specifications:
/// - Header gradient: 0% #DCF2FF to 100% #A4DDFF
/// - Title: "Messages" in DM Sans extrabold (#1A5DC9) with yellow underline (#FECE01)
/// - Search bar with `where.webp` icon and blue stroke
/// - Filter chips for "All" and "Unread"
/// - Unread message highlighting: #FFFBE9 background with #FECE01 left accent bar
/// - Gray circular profile picture placeholders (#D9D9D9)
class MessagesView extends ConsumerStatefulWidget {
  const MessagesView({super.key});

  @override
  ConsumerState<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends ConsumerState<MessagesView> {
  late final TextEditingController _searchController;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(messagesViewModelProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagesViewModelProvider);
    final viewModel = ref.read(messagesViewModelProvider.notifier);
    final filteredThreads = state.filteredThreads;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with gradient and DM Sans extrabold title
          const MessagesHeader(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('New chat'),
                onPressed: () async {
                  final thread = await Navigator.of(context)
                      .push<MessageThread>(
                        MaterialPageRoute(builder: (_) => const NewChatView()),
                      );
                  if (!context.mounted || thread == null) return;
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ChatConversationView(thread: thread),
                    ),
                  );
                  if (mounted) {
                    ref.read(messagesViewModelProvider.notifier).refresh();
                  }
                },
              ),
              IconButton(
                tooltip: 'Refresh messages',
                onPressed: viewModel.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                state.error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          // Search bar and filter pills
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MessagesSearchBar(
                  controller: _searchController,
                  onChanged: viewModel.setSearchQuery,
                ),
                const SizedBox(height: 14),
                MessagesFilterChips(
                  selectedFilter: state.activeFilter,
                  onSelectFilter: viewModel.setFilter,
                ),
              ],
            ),
          ),

          // Message threads list
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredThreads.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: Color(0xFFB0BEC5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.searchQuery.isNotEmpty
                              ? 'No messages found for "${state.searchQuery}"'
                              : state.activeFilter == MessagesFilter.unread
                              ? 'No unread messages'
                              : 'No conversations yet. Start a new chat.',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            color: const Color(0xFF78909C),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: filteredThreads.length,
                    itemBuilder: (context, index) {
                      final thread = filteredThreads[index];
                      return MessageTile(
                        thread: thread,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  ChatConversationView(thread: thread),
                            ),
                          );
                          if (mounted) {
                            ref
                                .read(messagesViewModelProvider.notifier)
                                .refresh();
                          }
                        },
                        onLongPress: () {
                          MessageActionSheet.show(
                            context: context,
                            thread: thread,
                            onToggleRead: () =>
                                viewModel.toggleThreadReadStatus(thread.id),
                            onDelete: () =>
                                viewModel.deleteConversation(thread.id),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
