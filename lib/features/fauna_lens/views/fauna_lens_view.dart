import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/create_post/viewmodels/create_post_viewmodel.dart';
import 'package:faunawatch/features/fauna_lens/viewmodels/fauna_lens_viewmodel.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_camera_screen.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_review_screen.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// FaunaLens: take or choose a photo of an animal, then decide what to do with
/// it. Shows the camera until there is a photo, and the review after that.
class FaunaLensView extends ConsumerStatefulWidget {
  const FaunaLensView({super.key});

  @override
  ConsumerState<FaunaLensView> createState() => _FaunaLensViewState();
}

class _FaunaLensViewState extends ConsumerState<FaunaLensView>
    with WidgetsBindingObserver {
  FaunaLensViewModel get _viewModel =>
      ref.read(faunaLensViewModelProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewModel.startCamera();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _viewModel.pauseCamera();
    } else if (state == AppLifecycleState.resumed) {
      _viewModel.resumeCamera();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _toggleFlash() async {
    final changed = await _viewModel.toggleFlash();
    if (!changed && mounted) {
      _showMessage("This camera doesn't have a flash.");
    }
  }

  Future<void> _switchLens() async {
    final switched = await _viewModel.switchLens();
    if (!switched && mounted) {
      _showMessage("This device doesn't have another camera.");
    }
  }

  Future<void> _capture() async {
    final captured = await _viewModel.capture();
    if (!captured && mounted) {
      _showMessage("Couldn't take the photo. Please try again.");
    }
  }

  void _askAi() {
    // TODO(team): Decide what Ask AI opens. The repository has no AI provider
    // client or suggestion result screen yet, so nothing can be identified.
    _showMessage("AI suggestions aren't available yet.");
  }

  void _skipAi() {
    final photo = ref.read(faunaLensViewModelProvider).photo;
    if (photo == null) return;
    ref.read(createPostViewModelProvider.notifier).usePhoto(photo);
    ref
        .read(shellViewModelProvider.notifier)
        .selectDestination(ShellDestination.addPost);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(faunaLensViewModelProvider);
    final photo = state.photo;

    return PopScope(
      canPop: photo == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _viewModel.discardPhoto();
      },
      child: photo == null
          ? FaunaLensCameraScreen(
              state: state,
              previewController: _viewModel.previewController,
              onClose: () => Navigator.of(context).pop(),
              onToggleFlash: _toggleFlash,
              onPickFromGallery: _viewModel.pickFromGallery,
              onCapture: _capture,
              onSwitchLens: _switchLens,
              onRetryCamera: _viewModel.startCamera,
            )
          : FaunaLensReviewScreen(
              photo: photo,
              onBack: _viewModel.discardPhoto,
              onAskAi: _askAi,
              onChangePhoto: photo.source == FaunaLensPhotoSource.gallery
                  ? _viewModel.pickFromGallery
                  : _viewModel.discardPhoto,
              onSkipAi: _skipAi,
            ),
    );
  }
}
