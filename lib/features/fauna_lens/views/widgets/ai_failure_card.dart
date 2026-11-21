import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_theme.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/ai_result_cards.dart';
import 'package:flutter/material.dart';

/// Explains why the AI could not help, with a way forward: add or check a
/// key, or try again.
class AiFailureCard extends StatelessWidget {
  const AiFailureCard({
    super.key,
    required this.failure,
    this.photoSubject = '',
    required this.onRetry,
    required this.onOpenKeySettings,
  });

  final IdentificationFailure failure;
  final String photoSubject;
  final VoidCallback onRetry;
  final VoidCallback onOpenKeySettings;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (failure) {
      IdentificationFailure.noKey => (
        'Add an AI key first',
        'FaunaLens uses your own AI key to identify animals. Add one, then '
            "we'll try again.",
      ),
      IdentificationFailure.invalidKey => (
        "Your AI key didn't work",
        'The AI provider rejected your key. Check or replace it, then try '
            'again.',
      ),
      IdentificationFailure.rateLimited => (
        'The AI is busy',
        "The provider is busy or your key's limit was reached. Wait a "
            'moment and try again.',
      ),
      IdentificationFailure.unavailable => (
        "The AI isn't responding",
        'The AI provider is having trouble, or its model is no longer '
            'available. Please try again later.',
      ),
      IdentificationFailure.network => (
        "Couldn't reach the AI",
        'Check your internet connection and try again.',
      ),
      IdentificationFailure.unreadablePhoto => (
        "Couldn't read this photo",
        'Retake it or choose another photo.',
      ),
      IdentificationFailure.badResponse => (
        "Couldn't read the AI's answer",
        'Please try again.',
      ),
      IdentificationFailure.notAnimal => (
        'FaunaLens only identifies animals',
        '${photoSubject.isEmpty ? 'No animal was found in the boxes you chose.' : 'The boxes you chose seem to show $photoSubject, not an animal.'} '
            'Go back to choose other boxes, or retake the photo.',
      ),
      IdentificationFailure.signedOut => (
        'Sign in again',
        'Sign in to use AI suggestions.',
      ),
    };
    final opensKeys =
        failure == IdentificationFailure.noKey ||
        failure == IdentificationFailure.invalidKey;
    final canRetry =
        failure != IdentificationFailure.unreadablePhoto &&
        failure != IdentificationFailure.notAnimal &&
        failure != IdentificationFailure.signedOut;

    return AiResultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                opensKeys
                    ? Icons.key_rounded
                    : failure == IdentificationFailure.notAnimal
                    ? Icons.pets_rounded
                    : Icons.error_outline_rounded,
                color: FaunaLensTheme.of(context).accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: aiResultTitleStyle(context))),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: aiResultBodyStyle(context)),
          if (opensKeys || canRetry) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: FaunaLensTheme.of(context).accent,
                  foregroundColor: FaunaLensTheme.of(context).isDark
                      ? AppColors.darkSurface
                      : Colors.white,
                ),
                onPressed: opensKeys ? onOpenKeySettings : onRetry,
                child: Text(
                  opensKeys
                      ? (failure == IdentificationFailure.noKey
                            ? 'Add an AI key'
                            : 'Check AI keys')
                      : 'Try again',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
