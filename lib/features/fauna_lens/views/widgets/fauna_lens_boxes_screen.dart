import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_theme.dart';
import 'package:faunawatch/core/widgets/pill_button.dart';
import 'package:faunawatch/features/fauna_lens/models/animal_box.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/viewmodels/animal_boxes_viewmodel.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/ai_failure_card.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/ai_result_cards.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/boxed_photo.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_ai_result_screen.dart';
import 'package:faunawatch/features/settings/views/ai_integration_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Choose animals": the user's AI provider finds the animals in [photo] and
/// boxes each in its own colour. The user picks up to three, or draws a box
/// by hand, then opens the AI Result for them. The chosen box last tapped or
/// drawn can be resized by its corners, moved, or deleted with its ✕.
///
/// Pops with the [AiResultChoice] made on the AI Result, or null on back.
class FaunaLensBoxesScreen extends ConsumerStatefulWidget {
  const FaunaLensBoxesScreen({super.key, required this.photo});

  final FaunaLensPhoto photo;

  @override
  ConsumerState<FaunaLensBoxesScreen> createState() =>
      _FaunaLensBoxesScreenState();
}

class _FaunaLensBoxesScreenState extends ConsumerState<FaunaLensBoxesScreen> {
  bool _isDrawing = false;

  AnimalBoxesViewModel get _viewModel =>
      ref.read(animalBoxesViewModelProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _find();
    });
  }

  void _find() => _viewModel.findAnimals(widget.photo.path);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _toggle(AnimalBox box) => _afterChoosing(_viewModel.toggle(box));

  void _tapBox(AnimalBox box) => _afterChoosing(_viewModel.tapBox(box));

  void _afterChoosing(ChooseBoxOutcome outcome) {
    if (outcome == ChooseBoxOutcome.limitReached) {
      _showMessage(
        'You can choose up to ${AnimalBox.maxChosen} animals. '
        'Tap a chosen name below to unchoose it first.',
      );
    }
  }

  void _boxDrawn(double x1, double y1, double x2, double y2) {
    setState(() => _isDrawing = false);
    final added = _viewModel.addDrawnBox(x1: x1, y1: y1, x2: x2, y2: y2);
    if (!added) {
      _showMessage('That box was too small. Drag across the whole animal.');
    }
  }

  Future<void> _openKeySettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AiIntegrationView()));
    if (mounted) _find();
  }

  Future<void> _analyse() async {
    final boxes = ref.read(animalBoxesViewModelProvider).chosenBoxes;
    final choice = await Navigator.of(context).push<AiResultChoice>(
      MaterialPageRoute(
        builder: (_) =>
            FaunaLensAiResultScreen(photo: widget.photo, boxes: boxes),
      ),
    );
    if (choice != null && mounted) Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(animalBoxesViewModelProvider);
    final isGallery = widget.photo.source == FaunaLensPhotoSource.gallery;
    final chosenCount = state.chosen.length;
    final colors = FaunaLensTheme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: colors.statusBar,
      child: Scaffold(
        backgroundColor: colors.page,
        body: Column(
          children: [
            FaunaLensPageHeader(
              title: 'Choose animals',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      BoxedPhoto(
                        path: widget.photo.path,
                        boxes: state.boxes,
                        chosen: state.chosen,
                        onTapBox: _tapBox,
                        isDrawing: _isDrawing,
                        drawingColor: AnimalBox.nextColor(state.boxes),
                        onBoxDrawn: _boxDrawn,
                        active: state.active,
                        onBoxChanged: _viewModel.updateBox,
                        onDeleteBox: (box) => _viewModel.deleteBox(box.color),
                      ),
                      if (state.isFinding) const _FindingBadge(),
                    ],
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.failure != null) ...[
                        AiFailureCard(
                          failure: state.failure!,
                          onRetry: _find,
                          onOpenKeySettings: _openKeySettings,
                        ),
                        const SizedBox(height: 10),
                      ],
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _guidance(state),
                          style: aiResultBodyStyle(context),
                        ),
                      ),
                      if (state.boxes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final box in state.boxes)
                              _BoxChip(
                                box: box,
                                isChosen: state.isChosen(box),
                                onTap: () => _toggle(box),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      PillButton(
                        label: chosenCount > 1
                            ? 'Analyse $chosenCount animals'
                            : 'Analyse animal',
                        primaryText: AppColors.faunaLensBlue,
                        onPressed: state.canAnalyse ? _analyse : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: isGallery ? (_isDrawing ? 4 : 3) : 1,
                            child: PillButton(
                              label: _isDrawing
                                  ? 'Cancel drawing'
                                  : 'Draw a box',
                              isPrimary: false,
                              secondaryFill: colors.outlineFill,
                              secondaryBorder: colors.outlineBorder,
                              secondaryText: colors.outlineText,
                              onPressed: state.canDrawBox || _isDrawing
                                  ? () =>
                                        setState(() => _isDrawing = !_isDrawing)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: isGallery ? 5 : 1,
                            child: PillButton(
                              label: isGallery
                                  ? 'Choose another photo'
                                  : 'Retake photo',
                              isPrimary: false,
                              secondaryFill: colors.outlineFill,
                              secondaryBorder: colors.outlineBorder,
                              secondaryText: colors.outlineText,
                              onPressed: () => Navigator.of(
                                context,
                              ).pop(const RetakeFromAiResult()),
                            ),
                          ),
                        ],
                      ),
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

  String _guidance(AnimalBoxesState state) {
    if (_isDrawing) {
      return 'Drag across the animal to draw a box around it.';
    }
    if (state.isFinding) return 'Finding the animals in your photo…';
    if (state.foundNothing) {
      return 'No animal was found. Draw a box around the animal yourself, '
          'or retake the photo.';
    }
    if (state.boxes.isEmpty) {
      return 'You can still draw a box around the animal yourself.';
    }
    final active = state.activeBox;
    if (active != null) {
      final edit =
          'Drag a corner of the ${active.color.value} box to resize it, '
          'or drag inside it to move it. Tap ✕ to delete it.';
      return state.boxes.length > 1
          ? 'Tap the animals you want to report, up to '
                '${AnimalBox.maxChosen}. $edit'
          : edit;
    }
    return 'Tap the animals you want to report, up to ${AnimalBox.maxChosen}. '
        'The AI will look only inside the boxes you choose.';
  }
}

class _FindingBadge extends StatelessWidget {
  const _FindingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Finding animals…',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// One box in the list under the photo: its colour, its name, and whether it
/// is chosen. Tapping it does the same as tapping the box on the photo.
class _BoxChip extends StatelessWidget {
  const _BoxChip({
    required this.box,
    required this.isChosen,
    required this.onTap,
  });

  final AnimalBox box;
  final bool isChosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(box.color.argb);
    final colors = FaunaLensTheme.of(context);
    return Semantics(
      button: true,
      selected: isChosen,
      label: '${box.label}, ${box.color.value} box',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isChosen ? color.withValues(alpha: 0.18) : colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color, width: isChosen ? 2 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isChosen
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                box.label,
                style: GoogleFonts.dmSans(
                  color: colors.title,
                  fontSize: 13,
                  fontWeight: isChosen ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
