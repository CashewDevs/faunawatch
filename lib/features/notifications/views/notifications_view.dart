import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/widgets/inset_centered_scroll.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';
import 'package:faunawatch/features/notifications/viewmodels/notifications_viewmodel.dart';
import 'package:faunawatch/features/notifications/views/widgets/notification_action_sheet.dart';
import 'package:faunawatch/features/notifications/views/widgets/notification_tile.dart';
import 'package:faunawatch/features/notifications/views/widgets/notifications_filter_chips.dart';
import 'package:faunawatch/features/notifications/views/widgets/notifications_header.dart';

/// Screen displaying user notifications with filters and action options.
///
/// Implements visual specifications:
/// - Header gradient: horizontal 0% #DCF2FF to 100% #A4DDFF
/// - Title: "Notifications" in DM Sans extrabold (#1A5DC9) with yellow underline (#FECE01)
/// - Filter chips for "All" and "Unread"
/// - Unread notification highlighting: #FFFBE9 background with #FECE01 left accent bar
/// - Gray circular icon placeholders (#D9D9D9)
/// - Long-press modal sheet to mark as read/unread or delete
///
/// Shows a loading indicator, an error with retry, or an empty message when
/// there is nothing to list. The list can be pulled to refresh and loads older
/// notifications on request.
class NotificationsView extends ConsumerWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsViewModelProvider);
    final viewModel = ref.read(notificationsViewModelProvider.notifier);
    final filteredItems = state.filteredItems;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with horizontal gradient and DM Sans extrabold title
          const NotificationsHeader(),

          // Filter pills (All, Unread)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: NotificationsFilterChips(
              selectedFilter: state.activeFilter,
              onSelectFilter: viewModel.setFilter,
            ),
          ),

          if (state.error != null && state.items.isNotEmpty)
            _ErrorBanner(message: state.error!, isDark: isDark),

          // Notifications list
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && state.items.isEmpty
                ? _MessageState(
                    isDark: isDark,
                    icon: Icons.cloud_off_outlined,
                    subtitle: state.error!,
                    actionLabel: 'Try again',
                    onAction: viewModel.retry,
                    onRefresh: viewModel.refresh,
                  )
                : filteredItems.isEmpty
                ? _MessageState(
                    isDark: isDark,
                    icon: Icons.notifications_off_outlined,
                    title: state.activeFilter == NotificationsFilter.unread
                        ? 'No unread notifications'
                        : 'No notifications',
                    subtitle: state.activeFilter == NotificationsFilter.unread
                        ? "You're all caught up."
                        : "You're all caught up. Updates on your reports, "
                              'comments and chats will show up here.',
                    onRefresh: viewModel.refresh,
                  )
                : RefreshIndicator(
                    onRefresh: viewModel.refresh,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      // Leave room for the nav bar the shell draws over the body.
                      padding: EdgeInsets.only(bottom: bottomInset),
                      itemCount: filteredItems.length + (state.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == filteredItems.length) {
                          return _LoadMoreFooter(
                            isLoading: state.isLoadingMore,
                            onPressed: viewModel.loadMore,
                          );
                        }
                        final item = filteredItems[index];
                        return NotificationTile(
                          item: item,
                          onTap: () {
                            // TODO(open question): open the related report or
                            // chat from item.reportId / item.threadId. Reports
                            // have no route by id yet, and
                            // ChatConversationView needs a MessageThread (name
                            // and avatar) that a notification does not carry,
                            // so no navigation is built here.
                            if (item.isUnread) {
                              viewModel.markAsRead(item.id);
                            }
                          },
                          onLongPress: () {
                            NotificationActionSheet.show(
                              context: context,
                              item: item,
                              onToggleRead: () =>
                                  viewModel.toggleReadStatus(item.id),
                              onDelete: () =>
                                  viewModel.deleteNotification(item.id),
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

/// Full-area message (empty list or load failure) that can be pulled to
/// refresh.
///
/// Centred in the area above the shell's nav bar (see [InsetCenteredScroll]).
class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.isDark,
    required this.icon,
    required this.onRefresh,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final bool isDark;
  final IconData icon;
  final String? title;
  final String? subtitle;
  final Future<void> Function() onRefresh;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return InsetCenteredScroll(
      onRefresh: onRefresh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface
                    : AppColors.messagesPfpPlaceholder.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: isDark
                    ? AppColors.darkIconMuted
                    : const Color(0xFF78909C),
              ),
            ),
            const SizedBox(height: 20),
            if (title != null)
              Text(
                title!,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : const Color(0xFF263238),
                ),
              ),
            if (title != null && subtitle != null) const SizedBox(height: 6),
            if (subtitle != null)
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF78909C),
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error line above a list that is still showing.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.isDark});

  final String message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: isDark ? AppColors.darkErrorBackground : const Color(0xFFFFEBEE),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Text(
        message,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.darkErrorText : const Color(0xFFB71C1C),
        ),
      ),
    );
  }
}

/// End of the list: loads the next page of older notifications.
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onPressed,
                child: const Text('Load older notifications'),
              ),
      ),
    );
  }
}
