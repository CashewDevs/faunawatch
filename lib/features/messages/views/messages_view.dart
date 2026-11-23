import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/core/widgets/inset_centered_scroll.dart';
import 'package:faunawatch/features/messages/viewmodels/messages_viewmodel.dart';
import 'package:faunawatch/features/messages/views/chat_conversation_view.dart';
import 'package:faunawatch/features/messages/views/new_chat_view.dart';
import 'package:faunawatch/features/messages/views/widgets/message_action_sheet.dart';
import 'package:faunawatch/features/messages/views/widgets/message_tile.dart';
import 'package:faunawatch/features/messages/views/widgets/messages_filter_chips.dart';
import 'package:faunawatch/features/messages/views/widgets/messages_header.dart';
import 'package:faunawatch/features/messages/views/widgets/messages_search_bar.dart';

/// Screen displaying the conversation message threads with search, pull-to-refresh,
/// a New Chat pill beside the search bar, and All/Unread filters.
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

  Future<void> _openNewChat() async {
    final thread = await Navigator.of(context).push<MessageThread>(
      MaterialPageRoute(builder: (_) => const NewChatView()),
    );
    if (!mounted || thread == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ChatConversationView(thread: thread)),
    );
    if (mounted) {
      ref.read(messagesViewModelProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagesViewModelProvider);
    final viewModel = ref.read(messagesViewModelProvider.notifier);
    final filteredThreads = state.filteredThreads;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppPaletteColors.of(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with gradient and DM Sans extrabold title
          const MessagesHeader(),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Text(
                state.error!,
                style: TextStyle(
                  color: isDark ? AppColors.darkErrorText : Colors.red,
                ),
              ),
            ),

          // Search bar + New Chat pill and filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MessagesSearchBar(
                        controller: _searchController,
                        onChanged: viewModel.setSearchQuery,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _NewChatPillButton(
                      isDark: isDark,
                      palette: palette,
                      onTap: _openNewChat,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                MessagesFilterChips(
                  selectedFilter: state.activeFilter,
                  onSelectFilter: viewModel.setFilter,
                  selectedSortOrder: state.effectiveSortOrder,
                  onSelectSortOrder: viewModel.setSortOrder,
                ),
              ],
            ),
          ),

          // Message threads list with pull-to-refresh
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredThreads.isEmpty
                ? InsetCenteredScroll(
                    onRefresh: viewModel.refresh,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: isDark
                                ? AppColors.darkIconMuted
                                : const Color(0xFFB0BEC5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            state.searchQuery.isNotEmpty
                                ? 'No messages found for "${state.searchQuery}"'
                                : state.activeFilter == MessagesFilter.unread
                                ? 'No unread messages'
                                : 'No conversations yet. Start a new chat.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : const Color(0xFF78909C),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: viewModel.refresh,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      // Leave room for the nav bar the shell draws over the body.
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.paddingOf(context).bottom,
                      ),
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
          ),
        ],
      ),
    );
  }
}

class _NewChatPillButton extends StatelessWidget {
  const _NewChatPillButton({
    required this.isDark,
    required this.palette,
    required this.onTap,
  });

  final bool isDark;
  final AppPaletteColors palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDark
        ? palette.darkFilterSelected
        : const Color(0xFFFFF8DC);
    final borderColor = isDark
        ? palette.darkAccentBlue.withValues(alpha: 0.7)
        : palette.searchFieldStroke;
    final iconColor = isDark
        ? palette.darkAccentBlue
        : palette.messagesHeaderBlue;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.loginDarkText;

    return Semantics(
      button: true,
      label: 'New Chat',
      child: Material(
        color: backgroundColor,
        shape: StadiumBorder(side: BorderSide(color: borderColor, width: 1.4)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_comment_outlined, size: 19, color: iconColor),
                  const SizedBox(width: 7),
                  Text(
                    'New Chat',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
