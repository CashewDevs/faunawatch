import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/viewmodels/ai_key_settings_viewmodel.dart';
import 'package:faunawatch/features/settings/views/widgets/ai_key_dialog.dart';
import 'package:faunawatch/features/settings/views/widgets/ai_keys_agreement_sheet.dart';

/// Opens the key pop-up for [provider]'s main key: add or replace it (after
/// the AI Keys Agreement) or remove it. Screenshots are blocked while the
/// pop-up is open. Completes when it closes.
Future<void> editAiProviderKey(
  BuildContext context,
  WidgetRef ref,
  AiProvider provider, {
  bool allowRemove = true,
}) async {
  final viewModel = ref.read(aiKeySettingsViewModelProvider.notifier);
  final settings = await ref.read(aiKeySettingsViewModelProvider.future);
  if (!context.mounted) return;

  final name = provider.displayName;
  final messages = AiKeyMessages(context);
  String errorOr(String fallback) =>
      ref.read(aiKeySettingsViewModelProvider).valueOrNull?.errorMessage ??
      fallback;
  Future<void> openLink(Uri uri) async {
    if (!await viewModel.openExternalLink(uri)) {
      messages.show("Couldn't open the link. Please try again.");
    }
  }

  await viewModel.enableWindowSecurity();
  try {
    if (!context.mounted) return;
    await showAiKeyDialog(
      context,
      provider: provider,
      hasKey: settings.configuredProviders[provider] ?? false,
      onGetKey: () => openLink(provider.keyConsoleUri),
      onSave: (apiKey) async {
        final agreed = await confirmAiKeysAgreement(
          context,
          provider,
          onOpenTerms: () => openLink(provider.termsUri),
        );
        if (!agreed) return false;
        viewModel.selectProvider(provider);
        final saved = await viewModel.saveKey(apiKey);
        messages.show(
          saved
              ? '$name key saved.'
              : errorOr('Could not save the key. Please try again.'),
        );
        return saved;
      },
      onRemove: allowRemove
          ? () async {
              final confirmed = await confirmAiKeyRemoval(
                context,
                title: 'Remove $name key?',
                message:
                    "FaunaLens won't be able to use $name until you add a "
                    'key again.',
              );
              if (!confirmed) return false;
              viewModel.selectProvider(provider);
              final removed = await viewModel.removeKey();
              messages.show(
                removed
                    ? '$name key removed.'
                    : errorOr('Could not remove the key. Please try again.'),
              );
              return removed;
            }
          : null,
    );
  } finally {
    await viewModel.disableWindowSecurity();
  }
}

/// Shows the AI Keys Agreement for [provider], with its full text one tap
/// away. Resolves to true only when the user agrees.
Future<bool> confirmAiKeysAgreement(
  BuildContext context,
  AiProvider provider, {
  required VoidCallback onOpenTerms,
}) async {
  if (!context.mounted) return false;
  return showAiKeysAgreementSheet(
    context,
    provider: provider,
    onReadFullAgreement: () => showAiKeysFullAgreement(
      context,
      provider: provider,
      onOpenTerms: onOpenTerms,
    ),
  );
}

/// Asks before a key is deleted. Resolves to true when confirmed.
Future<bool> confirmAiKeyRemoval(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.signOutButtonRed,
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Remove',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Short messages at the bottom of the screen that opened a key pop-up.
class AiKeyMessages {
  AiKeyMessages(BuildContext context)
    : _messenger = ScaffoldMessenger.of(context);

  final ScaffoldMessengerState _messenger;

  void show(String message) => _messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
