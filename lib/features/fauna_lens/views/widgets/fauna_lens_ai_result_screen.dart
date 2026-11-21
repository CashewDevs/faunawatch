import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_theme.dart';
import 'package:faunawatch/core/widgets/pill_button.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/models/animal_box.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/viewmodels/ai_result_viewmodel.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/ai_failure_card.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/ai_result_cards.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/boxed_photo.dart';
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

/// "AI Result": asks the user's AI provider about the animals in [boxes] on
/// [photo] and shows one combined preliminary assessment. While the AI works,
/// the layout is shown as placeholders.
class FaunaLensAiResultScreen extends ConsumerStatefulWidget {
  const FaunaLensAiResultScreen({
    super.key,
    required this.photo,
    required this.boxes,
  });

  final FaunaLensPhoto photo;

  /// The animals the user chose, one to [AnimalBox.maxChosen].
  final List<AnimalBox> boxes;

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
    ref
        .read(aiResultViewModelProvider.notifier)
        .analyze(widget.photo.path, widget.boxes);
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
    final colors = FaunaLensTheme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: colors.statusBar,
      child: Scaffold(
        backgroundColor: colors.page,
        body: Column(
          children: [
            FaunaLensPageHeader(
              title: 'AI Result',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                children: [
                  _PhotoSummary(photo: widget.photo, boxes: widget.boxes),
                  const SizedBox(height: 16),
                  ...switch (state.status) {
                    AiResultStatus.analyzing => const [_LoadingBody()],
                    AiResultStatus.failed => [
                      AiFailureCard(
                        failure: state.failure!,
                        photoSubject: state.photoSubject,
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
                      label: 'Analyse again',
                      isPrimary: false,
                      secondaryFill: colors.outlineFill,
                      secondaryBorder: colors.outlineBorder,
                      secondaryText: colors.outlineText,
                      onPressed: state.isAnalyzing ? null : _analyze,
                    ),
                    const SizedBox(height: 10),
                    PillButton(
                      label: isGallery
                          ? 'Choose another photo'
                          : 'Retake photo',
                      isPrimary: false,
                      secondaryFill: colors.outlineFill,
                      secondaryBorder: colors.outlineBorder,
                      secondaryText: colors.outlineText,
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
                    style: aiResultBodyStyle(context).copyWith(fontSize: 12.5),
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
                    style: aiResultBodyStyle(context).copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AiResultInfoCard(
        label: 'SUGGESTED REPORT CATEGORY',
        children: [
          Text(
            result.category.label,
            style: aiResultBodyStyle(context).copyWith(fontSize: 12.5),
          ),
        ],
      ),
      const SizedBox(height: 12),
      AiResultCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What to do', style: aiResultTitleStyle(context)),
            const SizedBox(height: 6),
            Text(result.whatToDo, style: aiResultBodyStyle(context)),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'This is a preliminary AI-assisted assessment from '
        '${result.provider.displayName}. It is not a veterinary diagnosis, '
        'and it is not advice from a wildlife authority or emergency service.',
        style: aiResultMutedStyle(context),
      ),
    ];
  }
}

/// Thumbnail, "Preliminary AI assessment" chip and the always-on disclaimer.
class _PhotoSummary extends StatelessWidget {
  const _PhotoSummary({required this.photo, required this.boxes});

  final FaunaLensPhoto photo;
  final List<AnimalBox> boxes;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 68,
            child: BoxedPhoto(
              path: photo.path,
              boxes: boxes,
              chosen: {for (final box in boxes) box.color},
              showLabels: false,
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
                  color: FaunaLensTheme.of(context).badge,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '✦ Preliminary AI assessment',
                  style: GoogleFonts.dmSans(
                    color: FaunaLensTheme.of(context).badgeText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'AI can be wrong. Please check the results before you post.',
                style: aiResultBodyStyle(context).copyWith(fontSize: 12),
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

  Widget _block(
    FaunaLensTheme colors, {
    required double height,
    Color? color,
    Widget? child,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color ?? colors.card,
        borderRadius: BorderRadius.circular(14),
        border: color == null ? Border.all(color: colors.cardBorder) : null,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = FaunaLensTheme.of(context);
    return Semantics(
      label: 'Identifying the animal in your photo',
      liveRegion: true,
      child: FadeTransition(
        opacity: _pulse,
        child: Column(
          children: [
            _block(
              colors,
              height: 150,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Divider(color: colors.cardBorder),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _block(colors, height: 64, color: colors.invasive),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _block(colors, height: 96, color: colors.info)),
                const SizedBox(width: 10),
                Expanded(child: _block(colors, height: 96, color: colors.info)),
              ],
            ),
            const SizedBox(height: 12),
            _block(colors, height: 78),
          ],
        ),
      ),
    );
  }
}
