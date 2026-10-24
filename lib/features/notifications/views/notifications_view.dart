import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
class NotificationsView extends ConsumerWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsViewModelProvider);
    final viewModel = ref.read(notificationsViewModelProvider.notifier);
    final filteredItems = state.filteredItems;

    return Scaffold(
      backgroundColor: Colors.white,
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

          // Notifications list
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.notifications_off_outlined,
                          size: 48,
                          color: Color(0xFFB0BEC5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.activeFilter == NotificationsFilter.unread
                              ? 'No unread notifications'
                              : 'No notifications',
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
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return NotificationTile(
                        item: item,
                        onTap: () {
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
        ],
      ),
    );
  }
}
