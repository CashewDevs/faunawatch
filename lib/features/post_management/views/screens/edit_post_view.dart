import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/widgets/labeled_input_field.dart';
import 'package:faunawatch/features/create_post/models/post_photo_source.dart';
import 'package:faunawatch/features/create_post/views/widgets/attached_ai_analysis_card.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_ai_result_screen.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_boxes_screen.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_theme.dart';
import 'package:faunawatch/features/post_management/viewmodels/edit_post_viewmodel.dart';
import 'package:faunawatch/features/post_management/views/widgets/edit_post_photos.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';

/// "Edit post" for one of the user's own approved or pending posts. Pops
/// with an [EditPostOutcome] once saved.
class EditPostView extends ConsumerStatefulWidget {
  const EditPostView({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<EditPostView> createState() => _EditPostViewState();
}

class _EditPostViewState extends ConsumerState<EditPostView> {
  final _description = TextEditingController();
  bool _filled = false;

  EditPostViewModel get _vm =>
      ref.read(editPostViewModelProvider(widget.postId).notifier);

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<PostPhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _PhotoSourceSheet(),
    );
    if (mounted && source != null) await _vm.addPhotos(source);
  }

  /// Runs the same "Choose animals" and AI Result screens as a new post, on
  /// the cover photo.
  Future<void> _analyze() async {
    final cover = ref.read(editPostViewModelProvider(widget.postId)).cover;
    if (cover == null) return;
    final path = await _vm.coverForAnalysis();
    if (path == null || !mounted) return;
    final choice = await Navigator.of(context).push<AiResultChoice>(
      MaterialPageRoute(
        builder: (_) => FaunaLensBoxesScreen(
          photo: FaunaLensPhoto(
            path: path,
            source: FaunaLensPhotoSource.gallery,
            locationStatus: FaunaLensLocationStatus.missing,
          ),
        ),
      ),
    );
    // "Choose another photo" comes back here, where the photos can change.
    if (choice case UseAiResults(:final result)) {
      _vm.useAnalysis(cover.key, result);
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard your changes?'),
        content: const Text('Your post stays as it was.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final provider = editPostViewModelProvider(widget.postId);
    final state = ref.watch(provider);
    final colors = FaunaLensTheme.of(context);
    ref.listen(provider.select((state) => state.outcome), (_, outcome) {
      if (outcome != null) Navigator.of(context).pop(outcome);
    });
    // The caption is filled in once, when the post has loaded.
    if (!_filled && state.original != null) {
      _filled = true;
      _description.text = state.description;
    }

    return PopScope(
      canPop: !state.isSaving && (!state.hasChanges || state.outcome != null),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || state.isSaving) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.page,
        appBar: AppBar(
          backgroundColor: colors.header,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.aiResultBackChevron,
              size: 34,
            ),
          ),
          titleSpacing: 0,
          title: Text(
            'Edit post',
            style: GoogleFonts.dmSans(
              color: colors.accent,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.hasError
              ? _Notice(
                  text: 'Could not load this post. Check your connection.',
                  actionLabel: 'Try again',
                  onAction: _vm.retry,
                )
              : state.original == null
              ? const _Notice(text: "This post can't be edited any more.")
              : _form(context, state),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, EditPostState state) {
    final theme = Theme.of(context);
    final vm = _vm;
    final locked = state.isSaving;
    final category = state.category;
    final approved = state.original?.status == ReportStatus.approved;
    final note = state.sendsForReview
        ? approved
              ? 'Changing photos sends your post back for review. It leaves '
                    'the Feed and the map until an admin approves it again.'
              : 'Your post is still waiting for an admin to review it.'
        : approved
        ? 'Your post stays public.'
        : 'Your post is still waiting for an admin to review it.';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EditPostPhotos(
                photos: state.photos,
                freeSlots: state.freePhotoSlots,
                notice: state.photoNotice,
                onRemove: locked || state.isBusy ? null : vm.removePhoto,
                onMakeCover: locked || state.isBusy ? null : vm.makeCover,
                onAdd: locked || state.isBusy ? null : _addPhoto,
              ),
              if (state.photosChanged && state.coverChanged) ...[
                const SizedBox(height: 16),
                if (state.coverAnalysis case final analysis?)
                  AttachedAiAnalysisCard(
                    result: analysis,
                    onDetach: locked ? null : vm.removeAnalysis,
                  )
                else if (state.cover != null)
                  _AnalysisNeeded(
                    isBusy: state.isBusy,
                    onAnalyze: locked || state.isBusy ? null : _analyze,
                  ),
              ],
              const SizedBox(height: 20),
              if (category != null)
                Text(
                  'Category: ${category.label}',
                  style: GoogleFonts.dmSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              const SizedBox(height: 18),
              LabeledTextField(
                label: 'What did you observe?',
                icon: Icons.notes_rounded,
                controller: _description,
                enabled: !locked,
                minLines: 3,
                maxLines: 6,
                hintText: 'What was the animal doing? Did it look hurt?',
                onChanged: vm.editDescription,
              ),
              const SizedBox(height: 16),
              Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (state.error case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              if (locked) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
              ],
              _SaveButton(
                label: locked
                    ? 'Please wait…'
                    : state.sendsForReview && approved
                    ? 'Save and send for review'
                    : 'Save changes',
                onPressed: state.canSave ? vm.save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a FaunaLens analysis of a new cover photo.
class _AnalysisNeeded extends StatelessWidget {
  const _AnalysisNeeded({required this.isBusy, required this.onAnalyze});

  final bool isBusy;
  final VoidCallback? onAnalyze;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FaunaLensTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.accent.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome, size: 20, color: colors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your new cover photo needs a FaunaLens AI analysis before '
                  'you can save.',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAnalyze,
            icon: isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: const Text('Analyze with AI'),
          ),
        ],
      ),
    );
  }
}

/// The same gradient button as Create post's "Submit post".
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: enabled
            ? BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.onboardingButtonGradientStart,
                    AppColors.onboardingButtonGradientEnd,
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.faunaLensBlue, width: 2.0),
              )
            : const BoxDecoration(),
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: enabled ? Colors.transparent : null,
            foregroundColor: enabled ? const Color(0xFF003E43) : null,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            textStyle: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          icon: const Icon(Icons.check_rounded),
          label: Text(label),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (actionLabel case final label?)
              TextButton(onPressed: onAction, child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(PostPhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(PostPhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}
