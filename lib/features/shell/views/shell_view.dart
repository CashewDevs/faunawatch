import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:faunawatch/features/create_post/viewmodels/create_post_viewmodel.dart';
import 'package:faunawatch/features/fauna_lens/views/fauna_lens_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/feed/views/feed_view.dart';
import 'package:faunawatch/features/messages/views/messages_view.dart';
import 'package:faunawatch/features/notifications/views/notification_navigation.dart';
import 'package:faunawatch/features/notifications/views/notifications_view.dart';
import 'package:faunawatch/features/push/viewmodels/push_viewmodel.dart';
import 'package:faunawatch/features/profile/views/profile_view.dart';
import 'package:faunawatch/features/settings/views/ai_key_settings_view.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';
import 'package:faunawatch/features/shell/views/widgets/shell_header.dart';
import 'package:faunawatch/features/shell/views/widgets/shell_nav_bar.dart';

/// The root presentation widget containing the top app bar, active tab body,
/// and bottom navigation bar.
class ShellView extends ConsumerStatefulWidget {
  const ShellView({super.key});

  @override
  ConsumerState<ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends ConsumerState<ShellView> {
  @override
  void initState() {
    super.initState();
    // A push that launched the app waits here until the shell is shown.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPushTarget());
  }

  void _openPushTarget() {
    if (!mounted) return;
    final target = ref
        .read(pushViewModelProvider.notifier)
        .consumePendingTarget();
    if (target != null) {
      openNotificationTarget(Navigator.of(context), ref, target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDestination = ref.watch(shellViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Screenshots are allowed on every tab, Profile included. Only the AI key
    // screen (AiKeySetupView) blocks them, while it is open.

    // A push tapped while the app is open in the background.
    ref.listen(pushViewModelProvider.select((push) => push.pendingTarget), (
      _,
      target,
    ) {
      if (target != null) _openPushTarget();
    });

    return PopScope(
      // Back steps through the tabs instead of closing the app at once.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        extendBody: true,
        appBar: currentDestination == ShellDestination.feed
            ? const ShellHeader()
            : null,
        body: IndexedStack(
          index: currentDestination.index,
          children: [
            const FeedView(),
            const MessagesView(),
            // "+" opens FaunaLens on top instead of a tab.
            const SizedBox.shrink(),
            const NotificationsView(),
            const ProfileView(),
            const _PlaceholderDestinationView(
              title: 'Alerts View',
              icon: Icons.notifications_outlined,
            ),
            const AiKeySettingsView(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: ShellNavBar(
            currentDestination: currentDestination,
            onSelectDestination: (destination) {
              // "+" opens the FaunaLens camera; FaunaLens opens the post form
              // on top of itself once there is a photo.
              if (destination == ShellDestination.addPost) {
                // Every "+" starts a fresh post; a draft left behind earlier
                // is dropped.
                ref.read(createPostViewModelProvider.notifier).reset();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FaunaLensView(),
                  ),
                );
                return;
              }
              ref
                  .read(shellViewModelProvider.notifier)
                  .selectDestination(destination);
            },
          ),
        ),
      ),
    );
  }

  void _onBack() {
    switch (ref.read(shellViewModelProvider.notifier).back()) {
      case ShellBackResult.moved:
        ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      case ShellBackResult.confirmExit:
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: ShellViewModel.exitWindow,
            ),
          );
      case ShellBackResult.exit:
        ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
        SystemNavigator.pop();
    }
  }
}

/// Internal placeholder widget for shell destinations before feature implementation.
class _PlaceholderDestinationView extends StatelessWidget {
  const _PlaceholderDestinationView({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Feature pending implementation',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
