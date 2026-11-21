import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';
import 'package:faunawatch/features/report_detail/views/screens/report_detail_screen.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';

/// Navigates to [target], as chosen by `notificationTargetFor`: a report opens
/// `ReportDetailScreen`, a chat switches the shell to the Messages tab (the
/// inbox, not a specific conversation). Shared by tapping a notification in
/// the list and tapping a push notification.
Future<void> openNotificationTarget(
  NavigatorState navigator,
  WidgetRef ref,
  NotificationTarget? target,
) async {
  switch (target) {
    case ReportTarget(:final reportId, :final showComments):
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ReportDetailScreen(
            reportId: reportId,
            showComments: showComments,
          ),
        ),
      );
    case MessagesTarget():
      ref
          .read(shellViewModelProvider.notifier)
          .selectDestination(ShellDestination.chats);
    case null:
      break;
  }
}
