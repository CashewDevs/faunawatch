import 'package:flutter/material.dart';
import 'package:faunawatch/features/community_map/models/community_map_state.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_post_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:faunawatch/features/community_map/viewmodels/community_map_viewmodel.dart';
import 'package:faunawatch/features/community_map/views/widgets/mapbox_map_canvas.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_guide_sheet.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_purpose_card.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_warning_demo_card.dart';
import 'package:faunawatch/features/community_map/models/warning_demo.dart';

/// Interactive Mapbox map for approximate community wildlife sightings.
class CommunityMapView extends ConsumerStatefulWidget {
  const CommunityMapView({super.key});

  @override
  ConsumerState<CommunityMapView> createState() => _CommunityMapViewState();
}

class _CommunityMapViewState extends ConsumerState<CommunityMapView> {
  Brightness? _lastBrightness;
  bool _showPurposeCard = true;
  bool _showDemoControls = true;
  bool _postDialogOpen = false;

  Future<void> _openPost() async {
    if (_postDialogOpen) return;
    _postDialogOpen = true;
    final viewModel = ref.read(communityMapViewModelProvider.notifier);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => MapPostDialog(
        onSeeMore: () {
          Navigator.pop(dialogContext);
          viewModel.seeMore();
        },
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
    center: Point(
      coordinates: Position(WarningDemo.longitude, WarningDemo.latitude),
    ),
    zoom: WarningDemo.zoom,
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
    final colorScheme = Theme.of(context).colorScheme;

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
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _MapTitleCard(
                          colorScheme: colorScheme,
                          onOpenPreview: () =>
                              setState(() => _showPurposeCard = true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _MapModeButton(
                        is3dEnabled: state.is3dEnabled,
                        onPressed: () {
                          ref
                              .read(communityMapViewModelProvider.notifier)
                              .toggle3d();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  // Leave the native map attribution visible below the card.
                  minimum: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 420,
                      maxHeight: constraints.maxHeight * 0.46,
                    ),
                    child: _showPurposeCard
                        ? MapPurposeCard(
                            onLearnMore: _openMapGuide,
                            onDismiss: () =>
                                setState(() => _showPurposeCard = false),
                          )
                        : _showDemoControls
                        ? MapWarningDemoCard(
                            level: state.demoLevel,
                            hasError: state.demoHasError,
                            onSelect: ref
                                .read(communityMapViewModelProvider.notifier)
                                .selectDemoLevel,
                            onRecenter: ref
                                .read(communityMapViewModelProvider.notifier)
                                .recenterDemo,
                            onDismiss: () =>
                                setState(() => _showDemoControls = false),
                          )
                        : ActionChip(
                            avatar: const Icon(Icons.radar, size: 18),
                            label: Text(
                              'Warning demo · ${state.demoLevel.label}',
                            ),
                            onPressed: () =>
                                setState(() => _showDemoControls = true),
                          ),
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

class _MapTitleCard extends StatelessWidget {
  const _MapTitleCard({required this.colorScheme, required this.onOpenPreview});

  final ColorScheme colorScheme;
  final VoidCallback onOpenPreview;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: colorScheme.surface.withValues(alpha: 0.94),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Community map',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onOpenPreview,
                  tooltip: 'Show map preview',
                  icon: const Icon(Icons.info_outline),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Cebu City, Philippines · Demo',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapModeButton extends StatelessWidget {
  const _MapModeButton({required this.is3dEnabled, required this.onPressed});

  final bool is3dEnabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = is3dEnabled ? '3D' : '2D';
    return Semantics(
      button: true,
      label: 'Switch to ${is3dEnabled ? '2D' : '3D'} map view',
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
        elevation: 4,
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onPressed,
          tooltip: 'Switch to ${is3dEnabled ? '2D' : '3D'}',
          icon: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
