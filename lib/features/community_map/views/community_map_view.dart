import 'package:flutter/material.dart';
import 'package:faunawatch/features/community_map/models/community_map_state.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_post_dialog.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_post_flip_transition.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:faunawatch/features/community_map/viewmodels/community_map_viewmodel.dart';
import 'package:faunawatch/features/community_map/views/widgets/mapbox_map_canvas.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_guide_sheet.dart';

/// Interactive Mapbox map for approximate community wildlife sightings.
class CommunityMapView extends ConsumerStatefulWidget {
  const CommunityMapView({super.key});

  @override
  ConsumerState<CommunityMapView> createState() => _CommunityMapViewState();
}

class _CommunityMapViewState extends ConsumerState<CommunityMapView> {
  Brightness? _lastBrightness;
  bool _postDialogOpen = false;

  Future<void> _openPost() async {
    if (_postDialogOpen) return;
    _postDialogOpen = true;
    final viewModel = ref.read(communityMapViewModelProvider.notifier);
    final preview = viewModel.selectedPreview!;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 420),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          MapPostFlipTransition(
            animation: animation,
            builder: (onThumbnailReady) => SafeArea(
              child: MapPostDialog(
                preview: preview,
                onThumbnailReady: onThumbnailReady,
                onSeeMore: () {
                  Navigator.pop(dialogContext);
                  viewModel.seeMore();
                },
              ),
            ),
          ),
    );
    _postDialogOpen = false;
    if (mounted) viewModel.dismissPost();
  }

  void _openMapGuide() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      builder: (_) => const MapGuideSheet(),
    );
  }

  // The initial viewport must remain stable after Mapbox has rendered it.
  // The service changes only the pitch for 2D/3D, preserving the user's
  // current center, zoom, and bearing.
  late final CameraViewportState _initialViewport = CameraViewportState(
    center: Point(coordinates: Position(122, 12)),
    zoom: 5,
    pitch: 55,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_lastBrightness != brightness) {
      _lastBrightness = brightness;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(communityMapViewModelProvider.notifier)
              .setBrightness(brightness);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CommunityMapState>(communityMapViewModelProvider, (
      previous,
      next,
    ) {
      if (next.selectedPostId != null &&
          previous?.selectedPostId != next.selectedPostId) {
        _openPost();
      }
    });
    final state = ref.watch(communityMapViewModelProvider);
    final canvasBuilder = ref.watch(mapboxMapCanvasBuilderProvider);
    final refreshLabel = state.isLoadingReports
        ? 'Loading reports'
        : state.reportsHaveError
        ? 'Could not load reports. Tap to retry'
        : state.reports.isEmpty
        ? 'No approved reports yet. Refresh'
        : 'Refresh reports (${state.reports.length} approved)';

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: canvasBuilder.build(
                  viewport: _initialViewport,
                  onMapCreated: ref
                      .read(communityMapViewModelProvider.notifier)
                      .onMapCreated,
                  onStyleLoaded: (_) {
                    ref
                        .read(communityMapViewModelProvider.notifier)
                        .onStyleLoaded();
                  },
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  minimum: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _MapControlButton(
                        tooltip: refreshLabel,
                        onPressed: state.isLoadingReports
                            ? null
                            : ref
                                  .read(communityMapViewModelProvider.notifier)
                                  .refreshReports,
                        icon: state.isLoadingReports
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.refresh,
                                color: state.reportsHaveError
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                              ),
                      ),
                      const SizedBox(width: 8),
                      _MapControlButton(
                        tooltip: 'About this map',
                        onPressed: _openMapGuide,
                        icon: const Icon(Icons.info_outline),
                      ),
                      const SizedBox(width: 8),
                      _MapControlButton(
                        tooltip: 'Switch to ${state.is3dEnabled ? '2D' : '3D'}',
                        onPressed: () => ref
                            .read(communityMapViewModelProvider.notifier)
                            .toggle3d(),
                        icon: Text(
                          state.is3dEnabled ? '3D' : '2D',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Consistent, accessible touch targets for the floating map controls.
class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
    elevation: 4,
    shape: const CircleBorder(),
    child: IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      icon: icon,
    ),
  );
}
