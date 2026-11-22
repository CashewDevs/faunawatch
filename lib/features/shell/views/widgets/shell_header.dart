import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/notifications/viewmodels/notifications_viewmodel.dart';
import 'package:faunawatch/features/notifications/views/notifications_view.dart';
import 'package:faunawatch/features/shell/views/search_view.dart';

/// Top application bar for the FaunaWatch dashboard.
///
/// Features a height of 60, #1A5DC9 background, app logo and wordmark on the
/// left, and a clickable search bar capsule (a search icon and a muted
/// "Search" hint) and a notifications bell on the right. The bell shows a red dot while anything is unread and opens the
/// notifications as a page on top. FaunaLens opens from the "+" button in the
/// bottom bar.
class ShellHeader extends ConsumerWidget implements PreferredSizeWidget {
  const ShellHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  void _onSearchTap(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SearchView()));
  }

  void _onNotificationsTap(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NotificationsView()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread = ref.watch(hasUnreadNotificationsProvider);
    final headerBlue = AppPaletteColors.of(context).shellHeaderBlue;

    return Container(
      height: 60 + MediaQuery.paddingOf(context).top,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top,
        left: 14,
        // The bell's 48 dp tap area brings its icon in line with the logo's
        // margin.
        right: 2,
      ),
      color: headerBlue,
      child: SizedBox(
        height: 60,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: FaunaWatch Logo & Wordmark
            Image.asset(AppAssets.appLogo, height: 36, fit: BoxFit.contain),
            const SizedBox(width: 8),
            Image.asset(AppAssets.appWordmark, height: 28, fit: BoxFit.contain),
            const SizedBox(width: 8),
            // Clickable Search Bar Capsule, kept on the right. It shrinks only
            // when the row is too narrow (the hint then ends in "…"), so the
            // bell always fits on small phones.
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  button: true,
                  label: 'Search',
                  // The visible "Search" hint is the same word, so it is not
                  // read out a second time.
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => _onSearchTap(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      key: const Key('shell_search_pill'),
                      height: 32,
                      padding: const EdgeInsets.only(left: 12, right: 16),
                      decoration: BoxDecoration(
                        color: AppPaletteColors.of(context).resolve(
                          Colors.white,
                          Theme.of(context).colorScheme.surface,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, color: headerBlue, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Search',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                color: AppPaletteColors.of(context).resolve(
                                  Colors.black54,
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            _NotificationsBell(
              hasUnread: hasUnread,
              badgeBorderColor: headerBlue,
              onTap: () => _onNotificationsTap(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bell button (48 dp tap area) with a red dot while anything is unread.
class _NotificationsBell extends StatelessWidget {
  const _NotificationsBell({
    required this.hasUnread,
    required this.badgeBorderColor,
    required this.onTap,
  });

  final bool hasUnread;
  final Color badgeBorderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: hasUnread ? 'Notifications, unread' : 'Notifications',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Notifications',
        // Lets the tap ripple show on top of the blue bar.
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: onTap,
            radius: 24,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    if (hasUnread)
                      Positioned(
                        top: 1,
                        right: 2,
                        child: Container(
                          key: const Key('notifications_unread_badge'),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.notifsBadgeRed,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: badgeBorderColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
