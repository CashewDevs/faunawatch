import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/feed/views/feed_view.dart';
import 'package:faunawatch/features/gallery/views/gallery_view.dart';
import 'package:faunawatch/features/messages/views/messages_view.dart';
import 'package:faunawatch/features/notifications/views/notifications_view.dart';
import 'package:faunawatch/features/profile/views/profile_view.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';
import 'package:faunawatch/features/shell/views/widgets/shell_header.dart';
import 'package:faunawatch/features/shell/views/widgets/shell_nav_bar.dart';

/// The root presentation widget containing the top app bar, active tab body,
/// and bottom navigation bar.
class ShellView extends ConsumerWidget {
  const ShellView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDestination = ref.watch(shellViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          _PlaceholderDestinationView(
            title: 'Map View',
            icon: Icons.map_outlined,
          ),
          MessagesView(),
          NotificationsView(),
          ProfileView(),
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
