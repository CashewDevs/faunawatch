import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/shell/views/search_view.dart';

/// Top application bar for the FaunaWatch dashboard.
///
/// Features a height of 60, #1A5DC9 background, app logo and wordmark on the left,
/// and a clickable search bar capsule on the right. FaunaLens opens from the
/// "+" button in the bottom bar.
class ShellHeader extends StatelessWidget implements PreferredSizeWidget {
  const ShellHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  void _onSearchTap(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SearchView()));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60 + MediaQuery.paddingOf(context).top,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top,
        left: 14,
        right: 14,
      ),
      color: AppPaletteColors.of(context).shellHeaderBlue,
      child: SizedBox(
        height: 60,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: FaunaWatch Logo & Wordmark
            Image.asset(AppAssets.appLogo, height: 36, fit: BoxFit.contain),
            const SizedBox(width: 8),
            Image.asset(AppAssets.appWordmark, height: 28, fit: BoxFit.contain),
            const Spacer(),
            // Clickable Search Bar Capsule
            Semantics(
              button: true,
              label: 'Search',
              child: GestureDetector(
                onTap: () => _onSearchTap(context),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
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
                      Icon(
                        Icons.search,
                        color: AppPaletteColors.of(context).shellHeaderBlue,
                        size: 18,
                      ),
                      SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
