import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:faunawatch/features/community_map/views/community_map_view.dart';
import 'package:faunawatch/features/create_post/viewmodels/create_post_viewmodel.dart';
import 'package:faunawatch/features/fauna_lens/views/fauna_lens_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/feed/views/feed_view.dart';
import 'package:faunawatch/features/messages/views/messages_view.dart';
import 'package:faunawatch/features/notifications/views/notification_navigation.dart';
import 'package:faunawatch/features/push/viewmodels/push_viewmodel.dart';
import 'package:faunawatch/features/profile/views/profile_view.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';
import 'package:faunawatch/features/shell/views/widgets/shell_header.dart';
import 'package:faunawatch/features/shell/views/widgets/shell_nav_bar.dart';
import 'package:faunawatch/features/suspension/models/account_suspension.dart';
import 'package:faunawatch/features/suspension/views/widgets/suspension_notices.dart';

/// The root presentation widget containing the top app bar, active tab body,
/// and bottom navigation bar.
class ShellView extends ConsumerStatefulWidget {
  const ShellView({super.key});

  @override
  ConsumerState<ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends ConsumerState<ShellView>
    with SingleTickerProviderStateMixin {
  /// How long the new tab takes to fade in.
  static const switchDuration = Duration(milliseconds: 250);

  late final AnimationController _switch = AnimationController(
    vsync: this,
    duration: switchDuration,
    value: 1,
  );
  late final Animation<double> _fadeIn = CurvedAnimation(
    parent: _switch,
    curve: Curves.easeOutCubic,
  );
  late final Animation<double> _zoomIn = Tween<double>(
    begin: 0.98,
    end: 1,
  ).animate(_fadeIn);

  // Mapbox is created on first use, then kept alive so switching tabs does not
  // reload the map or lose its camera position.
  bool _mapOpened = false;

  @override
  void initState() {
    super.initState();
    // A push that launched the app waits here until the shell is shown.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPushTarget());
  }

  @override
  void dispose() {
    _switch.dispose();
    super.dispose();
  }

  /// Fades the new tab in, unless the device asks for less motion.
  ///
  /// The map appears at once: on Android, Mapbox is a native view, and fading
  /// or zooming it makes every frame blend that view again, so the map
  /// stutters. Flutter-drawn tabs fade cheaply.
  void _playSwitch(ShellDestination destination) {
    if (destination == ShellDestination.map ||
        MediaQuery.disableAnimationsOf(context)) {
      _switch.value = 1;
    } else {
      _switch.forward(from: 0);
    }
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
    if (currentDestination == ShellDestination.map) _mapOpened = true;

    ref.listen(shellViewModelProvider, (previous, next) {
      if (previous != next) _playSwitch(next);
    });

    // Screenshots are allowed on every tab, Profile included. Only the AI key
    // screens and the key pop-up block them, while they are open.

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
        appBar:
            currentDestination == ShellDestination.feed ||
                currentDestination == ShellDestination.map
            ? const ShellHeader()
            : null,
        // Each tab keeps its state; the one being opened fades in.
        body: FadeTransition(
          key: const Key('shell_tab_fade'),
          opacity: _fadeIn,
          child: ScaleTransition(
            scale: _zoomIn,
            child: IndexedStack(
              index: currentDestination.index,
              sizing: StackFit.expand,
              children: [
                const FeedView(),
                if (_mapOpened)
                  const CommunityMapView()
                else
                  const SizedBox.shrink(),
                // "+" opens FaunaLens on top instead of a tab.
                const SizedBox.shrink(),
                const MessagesView(),
                const ProfileView(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: ShellNavBar(
            currentDestination: currentDestination,
            onSelectDestination: (destination) {
              // "+" opens the FaunaLens camera; FaunaLens opens the post form
              // on top of itself once there is a photo.
              if (destination == ShellDestination.addPost) {
                if (blockedBySuspension(context, ref, SuspendedAction.post)) {
                  return;
                }
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
