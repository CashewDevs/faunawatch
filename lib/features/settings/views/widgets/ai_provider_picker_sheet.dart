import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';

/// Lets the user choose an AI provider. Resolves to null when dismissed.
Future<AiProvider?> showAiProviderPickerSheet(
  BuildContext context, {
  required AiProvider selected,
  required Map<AiProvider, bool> hasKey,
}) {
  return showModalBottomSheet<AiProvider>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'AI provider',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final provider in AiProvider.fallbackOrder)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(
                provider.displayName,
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                (hasKey[provider] ?? false)
                    ? '${provider.tagline} · Key added'
                    : '${provider.tagline} · No key yet',
              ),
              trailing: provider == selected
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: AppPaletteColors.of(context).shellHeaderBlue,
                    )
                  : null,
              selected: provider == selected,
              onTap: () => Navigator.of(sheetContext).pop(provider),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
