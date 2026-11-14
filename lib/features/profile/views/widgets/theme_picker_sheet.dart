import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/features/profile/models/theme_palette.dart';
import 'package:faunawatch/features/profile/viewmodels/settings_viewmodel.dart';

/// Bottom modal sheet allowing the user to select an app accent theme palette.
class ThemePickerSheet extends ConsumerWidget {
  const ThemePickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsViewModelProvider);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Change Theme',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a nature-inspired accent palette for FaunaWatch',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: AppThemePalette.presets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final palette = AppThemePalette.presets[index];
                  final isSelected = settings.activePaletteId == palette.id;
                  final optionScheme = ColorScheme.fromSeed(
                    seedColor: Color(palette.primaryColorValue),
                    brightness: scheme.brightness,
                  );

                  return InkWell(
                    onTap: () {
                      ref
                          .read(settingsViewModelProvider.notifier)
                          .setPalette(palette.id);
                      Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? optionScheme.primaryContainer
                            : scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? optionScheme.primary
                              : scheme.outlineVariant,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(palette.primaryColorValue),
                              gradient: palette.id == AppThemePalette.apollo.id
                                  ? LinearGradient(
                                      colors: [
                                        Color(palette.primaryColorValue),
                                        Color(palette.accentColorValue),
                                      ],
                                    )
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(
                                    palette.primaryColorValue,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  palette.name,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? optionScheme.onPrimaryContainer
                                        : scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  palette.description,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: isSelected
                                        ? optionScheme.onPrimaryContainer
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: optionScheme.primary,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
