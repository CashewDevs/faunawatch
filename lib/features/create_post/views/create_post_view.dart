import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/widgets/labeled_input_field.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/create_post_state.dart';
import '../models/post_draft.dart';
import '../models/post_location.dart';
import '../models/post_photo_source.dart';
import '../viewmodels/create_post_viewmodel.dart';
import 'screens/location_picker_screen.dart';
import 'widgets/animated_check.dart';
import 'widgets/attached_ai_analysis_card.dart';
import 'widgets/location_preview_card.dart';
import 'widgets/post_photo_section.dart';

/// How the user left Create Post, for FaunaLens to act on. Plain back
/// returns null and goes back to "Use this photo?".
enum CreatePostExit {
  /// Back to the live camera for another photo.
  changePhoto,

  /// The post was submitted and the user tapped Done: go home.
  done,
}

/// Create Post, opened by FaunaLens on top of "Use this photo?" once there is
/// a photo. Pops with a [CreatePostExit].
class CreatePostView extends ConsumerStatefulWidget {
  const CreatePostView({super.key});
  @override
  ConsumerState<CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends ConsumerState<CreatePostView> {
  final _description = TextEditingController();
  final _species = TextEditingController();
  final _notes = TextEditingController();

  void _sync(CreatePostState state) {
    for (final pair in [
      (_description, state.description),
      (_species, state.species),
      (_notes, state.notes),
    ]) {
      if (pair.$1.text != pair.$2) {
        pair.$1.value = TextEditingValue(
          text: pair.$2,
          selection: TextSelection.collapsed(offset: pair.$2.length),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [_description, _species, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final initialLocation = ref.read(createPostViewModelProvider).location;
    final location = await Navigator.of(context).push<PostLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialLocation: initialLocation),
      ),
    );
    if (mounted && location != null) {
      ref.read(createPostViewModelProvider.notifier).setLocation(location);
    }
  }

  void _exit(CreatePostExit exit) => Navigator.of(context).pop(exit);

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<PostPhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _PhotoSourceSheet(),
    );
    if (mounted && source != null) {
      await ref.read(createPostViewModelProvider.notifier).addPhotos(source);
    }
  }

  void _showTips() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _PostingTips(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createPostViewModelProvider);
    final vm = ref.read(createPostViewModelProvider.notifier);
    ref.listen(createPostViewModelProvider, (_, next) => _sync(next));
    _sync(state);
    final submitted = state.submittedId != null;
    final colors = FaunaLensTheme.of(context);

    return PopScope(
      // A submission in progress can't be left; after submitting, back does
      // the same as Done.
      canPop: !state.isBusy && !submitted,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && submitted) _exit(CreatePostExit.done);
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
          leading: submitted
              ? null
              : IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.aiResultBackChevron,
                    size: 34,
                  ),
                ),
          titleSpacing: submitted ? null : 0,
          title: Text(
            submitted ? 'Post submitted for review' : 'Create post',
            style: GoogleFonts.dmSans(
              color: colors.accent,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            if (!submitted)
              IconButton(
                tooltip: 'Posting tips',
                color: colors.accent,
                onPressed: _showTips,
                icon: const Icon(Icons.info_outline_rounded),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: submitted
              ? _Submitted(onDone: () => _exit(CreatePostExit.done))
              : _form(context, state, vm),
        ),
      ),
    );
  }

  Widget _form(
    BuildContext context,
    CreatePostState state,
    CreatePostViewModel vm,
  ) {
    final theme = Theme.of(context);
    final busy = state.isBusy;
    final isDark = theme.brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PostPhotoSection(
                photoPath: state.photoPath,
                extraPhotoPaths: state.extraPhotoPaths,
                freeSlots: state.freePhotoSlots,
                notice: state.photoNotice,
                onRemove: busy ? null : vm.removePhoto,
                onRemoveExtra: busy ? null : vm.removeExtraPhoto,
                onAddPhoto: busy ? null : _addPhoto,
                onChangePhoto: busy
                    ? null
                    : () => _exit(CreatePostExit.changePhoto),
              ),
              if (state.aiResult != null) ...[
                const SizedBox(height: 16),
                AttachedAiAnalysisCard(
                  result: state.aiResult!,
                  onDetach: busy ? null : vm.removeAiResult,
                ),
              ],
              const SizedBox(height: 24),
              LabeledDropdownField<ReportCategory>(
                label: 'Category *',
                icon: Icons.category_outlined,
                value: state.category,
                hintText: 'Choose a category',
                helperText: state.aiResult == null
                    ? null
                    : 'Set by FaunaLens AI. Tap "Don\'t attach analysis" to choose it yourself.',
                items: [
                  for (final category in ReportCategory.values)
                    (category, category.label),
                ],
                onChanged: busy || state.aiResult != null
                    ? null
                    : (value) => vm.edit(category: value),
              ),
              const SizedBox(height: 18),
              LabeledTextField(
                label: 'What did you observe?',
                icon: Icons.notes_rounded,
                controller: _description,
                enabled: !busy,
                minLines: 3,
                maxLines: 6,
                hintText: 'What was the animal doing? Did it look hurt?',
                onChanged: (value) => vm.edit(description: value),
              ),
              const SizedBox(height: 18),
              LabeledTextField(
                label: 'Species (optional)',
                icon: Icons.pets_outlined,
                controller: _species,
                enabled: !busy,
                hintText: 'Your identification, if known',
                onChanged: (value) => vm.edit(species: value),
              ),
              const SizedBox(height: 24),
              Text(
                'Observation location *',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              LocationPreviewCard(
                hasLocation: state.hasLocation,
                label: state.locationLabel,
                previewUrl: (width, height) => vm.locationPreviewUrl(
                  width: width,
                  height: height,
                  isDarkMode: isDark,
                ),
                onOpenMap: busy ? null : _pickLocation,
              ),
              const SizedBox(height: 10),
              _CurrentLocationButton(
                isUsingCurrentLocation:
                    state.hasLocation &&
                    state.locationLabel == 'Current location',
                isDark: isDark,
                onLocate: busy ? null : vm.locate,
                onClear: busy ? null : vm.clearLocation,
              ),
              const SizedBox(height: 14),
              LabeledTextField(
                label: 'Additional notes (optional)',
                icon: Icons.edit_note_rounded,
                controller: _notes,
                enabled: !busy,
                minLines: 2,
                maxLines: 4,
                onChanged: (value) => vm.edit(notes: value),
              ),
              const SizedBox(height: 16),
              Text(
                state.aiResult == null
                    ? 'Posts are reviewed before appearing on the community map. Shared coordinates are approximate. No AI analysis attached.'
                    : 'Posts are reviewed before appearing on the community map. Shared coordinates are approximate.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      state.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              if (busy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
              ],
              SizedBox(
                height: 52,
                child: DecoratedBox(
                  key: const ValueKey('create_post_submit_container'),
                  decoration: state.canSubmit
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
                          border: Border.all(
                            color: AppColors.faunaLensBlue,
                            width: 2.0,
                          ),
                        )
                      : const BoxDecoration(),
                  child: FilledButton.icon(
                    onPressed: state.canSubmit ? vm.submit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: state.canSubmit
                          ? Colors.transparent
                          : null,
                      foregroundColor: state.canSubmit
                          ? const Color(0xFF003E43)
                          : null,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      textStyle: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.send_outlined),
                    label: Text(busy ? 'Please wait…' : 'Submit post'),
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

/// Full-width light-yellow button to capture or clear the user's current GPS
/// location, with a visual status indicator and an `×` icon when active.
class _CurrentLocationButton extends StatelessWidget {
  const _CurrentLocationButton({
    required this.isUsingCurrentLocation,
    required this.isDark,
    required this.onLocate,
    required this.onClear,
  });

  final bool isUsingCurrentLocation;
  final bool isDark;
  final VoidCallback? onLocate;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final accentBlue = isDark
        ? AppColors.darkAccentBlue
        : AppColors.faunaLensBlue;
    final backgroundColor = isDark
        ? AppColors.darkFilterSelected
        : (isUsingCurrentLocation
              ? AppColors.messagesFilterSelected
              : AppColors.galleryFilterButtonBackground);
    final checkGreen = isDark
        ? AppColors.darkIconGreen
        : AppColors.faunaLensChipCheck;

    return Container(
      key: const ValueKey('use_current_location_button'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isUsingCurrentLocation ? accentBlue : Colors.transparent,
          width: 1.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onLocate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.my_location_rounded,
                        size: 20,
                        color: accentBlue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Use current location',
                          style: GoogleFonts.dmSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: accentBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isUsingCurrentLocation
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        key: const ValueKey('current_location_indicator'),
                        size: 20,
                        color: isUsingCurrentLocation
                            ? checkGreen
                            : accentBlue.withValues(alpha: 0.55),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isUsingCurrentLocation)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: IconButton(
                  key: const ValueKey('clear_current_location_button'),
                  tooltip: 'Do not use current location',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                  icon: Icon(Icons.close_rounded, size: 20, color: accentBlue),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// What to add, and the safety reminder, behind the (i) button.
class _PostingTips extends StatelessWidget {
  const _PostingTips();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget tip(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share a wildlife observation',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            tip(
              Icons.photo_camera_outlined,
              'Add a clear photo of the animal.',
            ),
            tip(
              Icons.notes_rounded,
              'Add what you saw: the category, what happened and, if you '
              'know it, the species.',
            ),
            tip(
              Icons.location_on_outlined,
              'Mark where it happened on the map. Shared locations are '
              'approximate.',
            ),
            tip(
              Icons.health_and_safety_outlined,
              'Stay at a safe distance from wildlife. Never approach, touch '
              'or feed the animal.',
            ),
          ],
        ),
      ),
    );
  }
}

/// The animated check and Done, after submitting.
class _Submitted extends StatelessWidget {
  const _Submitted({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AnimatedCheck(color: AppColors.faunaLensYellow),
              const SizedBox(height: 24),
              Text(
                'Thanks for your report!',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your report is pending review. Once approved, it can appear on the community map with an approximate location.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppColors.onboardingButtonGradientStart,
                        AppColors.onboardingButtonGradientEnd,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: AppColors.faunaLensBlue,
                      width: 2,
                    ),
                  ),
                  child: FilledButton(
                    onPressed: onDone,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: const Color(0xFF003E43),
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      textStyle: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Done'),
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

/// Asks where an extra photo should come from.
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
