import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:faunawatch/features/community_map/viewmodels/community_map_viewmodel.dart';
import 'package:faunawatch/features/community_map/views/widgets/mapbox_map_canvas.dart';

/// Interactive Mapbox map for approximate community wildlife sightings.
class CommunityMapView extends ConsumerStatefulWidget {
  const CommunityMapView({super.key});

  @override
  ConsumerState<CommunityMapView> createState() => _CommunityMapViewState();
}

class _CommunityMapViewState extends ConsumerState<CommunityMapView> {
  Brightness? _lastBrightness;

  // The initial viewport must remain stable after Mapbox has rendered it.
  // The service changes only the pitch for 2D/3D, preserving the user's
  // current center, zoom, and bearing.
  late final CameraViewportState _initialViewport = CameraViewportState(
    center: Point(coordinates: Position(0, 20)),
    zoom: 1.5,
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
                        child: _MapTitleCard(colorScheme: colorScheme),
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
            ],
          );
        },
      ),
    );
  }
}

class _MapTitleCard extends StatelessWidget {
  const _MapTitleCard({required this.colorScheme});

  final ColorScheme colorScheme;

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
            Text(
              'Community map',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Explore with touch, pinch, and two-finger rotation.',
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
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
