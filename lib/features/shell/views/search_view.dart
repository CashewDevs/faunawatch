import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Screen opened when the search bar in the dashboard header is clicked.
///
/// Features a custom curved header with a chevron back button, "Search" title,
/// and a stroke-bordered search bar utilizing `where.webp`.
class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPaletteColors.of(
        context,
      ).resolve(Colors.white, Theme.of(context).colorScheme.surface),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header container with curved bottom corners
          Container(
            decoration: BoxDecoration(
              color: AppPaletteColors.of(context).searchHeaderBackground,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back Chevron button
                    Semantics(
                      button: true,
                      label: 'Back',
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Icon(
                          Icons.chevron_left_rounded,
                          color: AppPaletteColors.of(context).searchHeaderBlue,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // "Search" Extrabold Title
                    Text(
                      'Search',
                      style: GoogleFonts.dmSans(
                        color: AppPaletteColors.of(context).searchHeaderBlue,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search Input Field Container
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppPaletteColors.of(context).resolve(
                          Colors.white,
                          Theme.of(context).colorScheme.surface,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppPaletteColors.of(context).searchFieldStroke,
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Image.asset(
                            AppAssets.whereIcon,
                            width: 18,
                            height: 18,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              autofocus: true,
                              cursorColor: AppPaletteColors.of(
                                context,
                              ).searchHeaderBlue,
                              style: GoogleFonts.dmSans(
                                color: AppPaletteColors.of(context).resolve(
                                  Colors.black87,
                                  Theme.of(context).colorScheme.onSurface,
                                ),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search fauna, sightings, areas...',
                                hintStyle: GoogleFonts.dmSans(
                                  color: AppPaletteColors.of(context).resolve(
                                    Colors.black38,
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Search results / empty state placeholder
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 64,
                    color: AppPaletteColors.of(
                      context,
                    ).searchHeaderBlue.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Search FaunaWatch',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppPaletteColors.of(context).resolve(
                        AppColors.onboardingSubheadingDark,
                        Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find animals, encounters, or regional sightings.',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: AppPaletteColors.of(context).resolve(
                        Colors.black54,
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
