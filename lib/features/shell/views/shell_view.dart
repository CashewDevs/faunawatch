import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';

/// The root presentation widget containing the top app bar, active tab body,
/// and bottom navigation bar.
class ShellView extends ConsumerWidget {
  const ShellView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDestination = ref.watch(shellViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FaunaWatch'),
      ),
      body: IndexedStack(
        index: currentDestination.index,
        children: const [
          _PlaceholderDestinationView(
            title: 'Report View',
            icon: Icons.assignment_outlined,
          ),
          _PlaceholderDestinationView(
            title: 'Map View',
            icon: Icons.map_outlined,
          ),
          _PlaceholderDestinationView(
            title: 'Alerts View',
            icon: Icons.notifications_outlined,
          ),
          _PlaceholderDestinationView(
            title: 'Profile View',
            icon: Icons.person_outlined,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentDestination.index,
        onDestinationSelected: (index) {
          ref.read(shellViewModelProvider.notifier).selectIndex(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Report',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Internal placeholder widget for shell destinations before feature implementation.
class _PlaceholderDestinationView extends StatelessWidget {
  const _PlaceholderDestinationView({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
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
