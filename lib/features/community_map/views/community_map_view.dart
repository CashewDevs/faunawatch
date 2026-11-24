import 'package:flutter/material.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_spot_sheet.dart';
import 'package:faunawatch/features/public_profile/views/widgets/profile_preview_sheet.dart';
import 'package:faunawatch/features/fauna_guard/viewmodels/fauna_guard_viewmodel.dart';
import 'package:faunawatch/features/fauna_guard/views/widgets/fauna_guard_intro_dialog.dart';
import 'package:faunawatch/features/fauna_guard/views/widgets/fauna_guard_status.dart';
import 'package:faunawatch/features/community_map/models/community_map_state.dart';
import 'package:faunawatch/features/community_map/models/map_focus.dart';
import 'package:faunawatch/features/community_map/models/map_pin_filter.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_filter_sheet.dart';
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
  bool _guardDialogOpen = false;
  bool _filterOpen = false;
  late final AppLifecycleListener _lifecycle;
  late final FaunaGuardViewModel _guardViewModel;

  @override
  void initState() {
    super.initState();
    _guardViewModel = ref.read(faunaGuardViewModelProvider.notifier);
    _lifecycle = AppLifecycleListener(
      onPause: () => _guardViewModel.setForeground(false),
      onResume: () => _guardViewModel.setForeground(true),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _toggleGuard() async {
    final viewModel = ref.read(faunaGuardViewModelProvider.notifier);
    if (ref.read(faunaGuardViewModelProvider).isEnabled) {
      viewModel.disable();
      return;
    }
    if (_guardDialogOpen) return;
    _guardDialogOpen = true;
    final enable = await FaunaGuardIntroDialog.show(context);
    _guardDialogOpen = false;
    if (mounted && enable == true) await viewModel.enable();
  }

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
                onAuthorTap: (authorId) {
                  // The Profile tab is behind the card, so close it first.
                  // Anyone else's profile preview slides up over the card;
                  // closing it (or Back from the full profile) returns here.
                  if (authorId == ref.read(currentUserIdProvider).valueOrNull) {
                    Navigator.pop(dialogContext);
                  }
                  viewModel.openAuthor(
                    authorId,
                    (id) => ProfilePreviewSheet.show(dialogContext, id),
                  );
                },
              ),
            ),
          ),
    );
    _postDialogOpen = false;
    if (mounted) viewModel.dismissPost();
  }

  /// Lists the posts sharing the tapped pin; picking one opens its card.
  Future<void> _openSpot() async {
    final spot = ref.read(communityMapViewModelProvider).selectedSpot;
    if (spot == null) return;
    final viewModel = ref.read(communityMapViewModelProvider.notifier);
    final postId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      builder: (sheetContext) => MapSpotSheet(
        spot: spot,
        onPick: (id) => Navigator.pop(sheetContext, id),
      ),
    );
    if (!mounted) return;
    viewModel.dismissSpot();
    if (postId != null) viewModel.selectPost(postId);
  }

  /// Opens the tick boxes for which pins to show; Show applies them.
  Future<void> _openFilter() async {
    if (_filterOpen) return;
    _filterOpen = true;
    final viewModel = ref.read(communityMapViewModelProvider.notifier);
    final filter = await showModalBottomSheet<MapPinFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      builder: (sheetContext) => Padding(
        // Keeps the species search above the keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: MapFilterSheet(
          initial: ref.read(communityMapViewModelProvider).filter,
          categoryCounts: viewModel.categoryCounts,
          speciesOptionsFor: viewModel.speciesOptionsFor,
          countMatching: viewModel.countMatching,
        ),
      ),
    );
    _filterOpen = false;
    if (mounted && filter != null) await viewModel.setFilter(filter);
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
      if (next.selectedSpot != null &&
          previous?.selectedSpot != next.selectedSpot) {
        _openSpot();
      }
    });
    final state = ref.watch(communityMapViewModelProvider);
    final guard = ref.watch(faunaGuardViewModelProvider);
    final guardViewModel = ref.read(faunaGuardViewModelProvider.notifier);
    final canvasBuilder = ref.watch(mapboxMapCanvasBuilderProvider);
    final refreshLabel = state.isLoadingReports
        ? 'Loading reports'
        : state.reportsHaveError
        ? 'Could not load reports. Tap to retry'
        : state.reports.isEmpty
        ? 'No approved reports yet. Refresh'
        : state.filter.isActive
        ? 'Refresh reports (showing ${state.visibleReports.length} of '
              '${state.reports.length})'
        : 'Refresh reports (${state.reports.length} approved)';
    final showNoMatch =
        state.filter.isActive &&
        !state.isLoadingReports &&
        state.reports.isNotEmpty &&
        state.visibleReports.isEmpty;

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
                  // Loads the photo pins for the area now on screen.
                  onMapIdle: (_) {
                    ref
                        .read(communityMapViewModelProvider.notifier)
                        .onMapIdle();
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
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _MapFilterButton(
                            ticked: state.filter.tickedCount,
                            onPressed: _openFilter,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _MapControlButton(
                        tooltip: guard.isEnabled
                            ? 'Turn off FaunaGuard'
                            : 'Turn on FaunaGuard',
                        onPressed: _toggleGuard,
                        icon: Icon(
                          guard.isEnabled
                              ? Icons.shield
                              : Icons.shield_outlined,
                          color: guard.isEnabled
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
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
              if (state.privateFocus != null || showNoMatch)
                Positioned(
                  left: 12,
                  right: 12,
                  // Above the shell's floating nav bar.
                  bottom: MediaQuery.paddingOf(context).bottom + 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showNoMatch)
                        _NoMatchBanner(
                          onClear: ref
                              .read(communityMapViewModelProvider.notifier)
                              .clearFilter,
                        ),
                      if (showNoMatch && state.privateFocus != null)
                        const SizedBox(height: 8),
                      if (state.privateFocus != null)
                        _PrivateFocusBanner(
                          focus: state.privateFocus!,
                          onClose: ref
                              .read(communityMapViewModelProvider.notifier)
                              .dismissPrivateFocus,
                        ),
                    ],
                  ),
                ),
              if (guard.isEnabled || guard.message != null)
                Positioned(
                  top: 72,
                  left: 12,
                  right: 12,
                  child: SafeArea(
                    bottom: false,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.45,
                      ),
                      child: SingleChildScrollView(
                        child: FaunaGuardStatus(
                          state: guard,
                          onDismissAlert: guardViewModel.dismissAlert,
                          onDismissMessage: guardViewModel.dismissMessage,
                          onSettings: guardViewModel.openSettings,
                        ),
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

/// Explains the orange marker on the owner's own post.
class _PrivateFocusBanner extends StatelessWidget {
  const _PrivateFocusBanner({required this.focus, required this.onClose});
  final MapFocus focus;
  final VoidCallback onClose;

  String get _detail {
    final spot = focus.isExact ? 'exact' : 'approximate';
    return focus.isPublic
        ? "Your post's $spot spot. Others see its pin within about 100 m."
        : "Your post's $spot spot. It isn't on the public map.";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.96),
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFFF57C00),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${MapFocus.privateLabel}. ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: _detail),
                  ],
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
            IconButton(
              tooltip: 'Hide marker',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the filter hides every pin, e.g. after a refresh.
class _NoMatchBanner extends StatelessWidget {
  const _NoMatchBanner({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.96),
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Row(
          children: [
            Icon(
              Icons.filter_alt_off_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No pins match this filter.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            TextButton(onPressed: onClear, child: const Text('Clear filter')),
          ],
        ),
      ),
    );
  }
}

/// The pill that opens the pin filter; shows how many boxes are ticked.
class _MapFilterButton extends StatelessWidget {
  const _MapFilterButton({required this.ticked, required this.onPressed});

  final int ticked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = ticked > 0;
    final color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    return Tooltip(
      message: active ? 'Filter pins ($ticked selected)' : 'Filter pins',
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        elevation: 4,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, size: 20, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      active ? 'Filter · $ticked' : 'Filter',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
