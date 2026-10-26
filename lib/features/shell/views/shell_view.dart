import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/community_map/views/community_map_view.dart';
import 'package:faunawatch/features/feed/views/feed_view.dart';
import 'package:faunawatch/features/gallery/views/gallery_view.dart';
import 'package:faunawatch/features/messages/views/messages_view.dart';
import 'package:faunawatch/features/notifications/views/notifications_view.dart';
import 'package:faunawatch/features/profile/views/profile_view.dart';
import 'package:faunawatch/features/settings/viewmodels/ai_key_settings_viewmodel.dart';
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
  // Cached because `ref` cannot be used inside dispose().
  late final AiKeySettingsViewModel _aiKeySettingsViewModel;

  @override
  void initState() {
    super.initState();
    _aiKeySettingsViewModel = ref.read(aiKeySettingsViewModelProvider.notifier);
  }

  @override
  void dispose() {
    // Ensure FLAG_SECURE is cleared when the shell is removed from the tree.
    _aiKeySettingsViewModel.disableWindowSecurity();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentDestination = ref.watch(shellViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Toggle FLAG_SECURE based on whether the Profile (key-settings) tab
    // is active. This avoids blocking screenshots on unrelated tabs, which
    // happened previously because IndexedStack builds all children at
    // launch and initState ran unconditionally.
    ref.listen<ShellDestination>(shellViewModelProvider, (previous, next) {
      final viewModel = ref.read(aiKeySettingsViewModelProvider.notifier);
      if (next == ShellDestination.profile) {
        viewModel.enableWindowSecurity();
      } else if (previous == ShellDestination.profile) {
        viewModel.disableWindowSecurity();
      }
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      extendBody: true,
      appBar: currentDestination == ShellDestination.feed
          ? const ShellHeader()
          : null,
      body: IndexedStack(
        index: currentDestination.index,
        children: const [
          FeedView(),
          GalleryView(),
          CommunityMapView(),
          MessagesView(),
          NotificationsView(),
          ProfileView(),
          _PlaceholderDestinationView(
            title: 'Alerts View',
            icon: Icons.notifications_outlined,
          ),
          AiKeySettingsView(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: ShellNavBar(
          currentDestination: currentDestination,
          onSelectDestination: (destination) {
            ref
                .read(shellViewModelProvider.notifier)
                .selectDestination(destination);
          },
        ),
      ),
    );
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
