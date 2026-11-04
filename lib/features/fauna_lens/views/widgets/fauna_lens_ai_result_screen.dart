import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/widgets/local_image.dart';
import 'package:faunawatch/core/widgets/pill_button.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/viewmodels/ai_result_viewmodel.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/ai_result_cards.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/views/ai_key_setup_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// What the user chose on the AI Result screen. Going back returns null.
sealed class AiResultChoice {
  const AiResultChoice();
}

/// Carry the result into a new post.
class UseAiResults extends AiResultChoice {
  const UseAiResults(this.result);

  final AiIdentification result;
}

/// Take or choose another photo.
class RetakeFromAiResult extends AiResultChoice {
  const RetakeFromAiResult();
}

/// "AI Result": asks the user's AI provider about [photo] and shows its
/// preliminary assessment. While the AI works, the layout is shown as
/// placeholders.
class FaunaLensAiResultScreen extends ConsumerStatefulWidget {
  const FaunaLensAiResultScreen({super.key, required this.photo});

  final FaunaLensPhoto photo;

  @override
  ConsumerState<FaunaLensAiResultScreen> createState() =>
      _FaunaLensAiResultScreenState();
}

class _FaunaLensAiResultScreenState
    extends ConsumerState<FaunaLensAiResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _analyze();
    });
  }

  void _analyze() {
    ref.read(aiResultViewModelProvider.notifier).analyze(widget.photo.path);
  }

  Future<void> _openKeySettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AiKeySetupView.manage()),
    );
    if (mounted) _analyze();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiResultViewModelProvider);
    final result = state.result;
    final isGallery = widget.photo.source == FaunaLensPhotoSource.gallery;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _Header(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                children: [
                  _PhotoSummary(photo: widget.photo),
                  const SizedBox(height: 16),
                  ...switch (state.status) {
                    AiResultStatus.analyzing => const [_LoadingBody()],
                    AiResultStatus.failed => [
                      _FailureCard(
                        failure: state.failure!,
                        onRetry: _analyze,
                        onOpenKeySettings: _openKeySettings,
                      ),
                    ],
                    AiResultStatus.done => _resultBody(result!),
                  },
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PillButton(
                      label: 'Use these results',
                      onPressed: state.canUseResults
                          ? () =>
                                Navigator.of(context).pop(UseAiResults(result!))
                          : null,
                    ),
                    const SizedBox(height: 10),
                    PillButton(
                      label: isGallery
                          ? 'Choose another photo'
                          : 'Retake photo',
                      isPrimary: false,
                      onPressed: () =>
                          Navigator.of(context).pop(const RetakeFromAiResult()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _resultBody(AiIdentification result) {
    return [
      PossibleSpeciesCard(result: result),
      if (result.possibleInvasive) ...[
        const SizedBox(height: 12),
        const InvasiveHintCard(),
      ],
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AiResultInfoCard(
                label: 'VISIBLE CONDITION',
                children: [
                  Text(
                    result.visibleCondition,
                    style: aiResultBodyStyle().copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AiResultInfoCard(
                label: 'SEVERITY',
                children: [
                  SeverityChip(severity: result.severity),
                  const SizedBox(height: 6),
                  Text(
                    result.severityReason,
                    style: aiResultBodyStyle().copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AiResultCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What to do', style: aiResultTitleStyle()),
            const SizedBox(height: 6),
            Text(result.whatToDo, style: aiResultBodyStyle()),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'This is a preliminary AI-assisted assessment from '
        '${result.provider.displayName}. It is not a veterinary diagnosis, '
        'and it is not advice from a wildlife authority or emergency service.',
        style: aiResultMutedStyle(),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.aiResultHeader,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.aiResultBackChevron,
                  size: 34,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text(
                  'AI Result',
                  style: GoogleFonts.dmSans(
                    color: AppColors.faunaLensBlue,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thumbnail, "Preliminary AI assessment" chip and the always-on disclaimer.
class _PhotoSummary extends StatelessWidget {
  const _PhotoSummary({required this.photo});

  final FaunaLensPhoto photo;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LocalImage(
            photo.path,
            width: 68,
            height: 68,
            fit: BoxFit.cover,
            semanticLabel: 'Your photo',
            errorBuilder: (context, error, stackTrace) => const SizedBox(
              width: 68,
              height: 68,
              child: ColoredBox(color: AppColors.aiResultSkeleton),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.consentBadgeYellowBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '✦ Preliminary AI assessment',
                  style: GoogleFonts.dmSans(
                    color: AppColors.consentTitleNavy,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'AI can be wrong. Please check the results before you post.',
                style: aiResultBodyStyle().copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The result layout as soft placeholders while the AI is working.
class _LoadingBody extends StatefulWidget {
  const _LoadingBody();

  @override
  State<_LoadingBody> createState() => _LoadingBodyState();
}

class _LoadingBodyState extends State<_LoadingBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _block({required double height, Color? color, Widget? child}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: color == null
            ? Border.all(color: AppColors.aiResultCardBorder)
            : null,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Identifying the animal in your photo',
      liveRegion: true,
      child: FadeTransition(
        opacity: _pulse,
        child: Column(
          children: [
            _block(
              height: 150,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < 3; i++)
                      const Divider(color: AppColors.aiResultCardBorder),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _block(height: 64, color: AppColors.aiResultInvasiveBackground),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _block(
                    height: 96,
                    color: AppColors.aiResultInfoBackground,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _block(
                    height: 96,
                    color: AppColors.aiResultInfoBackground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _block(height: 78),
          ],
        ),
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({
    required this.failure,
    required this.onRetry,
    required this.onOpenKeySettings,
  });

  final IdentificationFailure failure;
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
        failure != IdentificationFailure.signedOut;

    return AiResultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                opensKeys ? Icons.key_rounded : Icons.error_outline_rounded,
                color: AppColors.faunaLensBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: aiResultTitleStyle())),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: aiResultBodyStyle()),
          if (opensKeys || canRetry) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.faunaLensBlue,
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
