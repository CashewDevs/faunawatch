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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                  color: const Color(0xFFCBD5E1),
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
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a nature-inspired accent palette for FaunaWatch',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: const Color(0xFF64748B),
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
                            ? Color(
                                palette.primaryColorValue,
                              ).withValues(alpha: 0.08)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? Color(palette.primaryColorValue)
                              : const Color(0xFFE2E8F0),
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
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  palette.description,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: Color(palette.primaryColorValue),
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
