import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../models/post_location.dart';
import '../../viewmodels/location_picker_viewmodel.dart';
import '../widgets/location_picker_canvas.dart';

class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key, this.initialLocation});
  final PostLocation? initialLocation;
  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _query = TextEditingController();
  Brightness? _lastBrightness;
  late final _initialCenter = widget.initialLocation?.isValid == true
      ? widget.initialLocation!
      : PostLocation.regionalFallback;
  late final _viewport = CameraViewportState(
    center: Point(
      coordinates: Position(_initialCenter.longitude, _initialCenter.latitude),
    ),
    zoom: widget.initialLocation?.isValid == true ? 15 : 5,
    pitch: 55,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(
              locationPickerViewModelProvider(widget.initialLocation).notifier,
            )
            .initialize();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_lastBrightness == brightness) return;
    _lastBrightness = brightness;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(
              locationPickerViewModelProvider(widget.initialLocation).notifier,
            )
            .setDarkMode(brightness == Brightness.dark);
      }
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = locationPickerViewModelProvider(widget.initialLocation);
    final state = ref.watch(provider);
    final vm = ref.read(provider.notifier);
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(
          'Choose observation location',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search city or address',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Search places',
                  onPressed: state.isSearching
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          vm.search();
                        },
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
              onChanged: vm.updateQuery,
              onSubmitted: (_) {
                FocusScope.of(context).unfocus();
                vm.search();
              },
            ),
          ),
          if (state.isSearching) const LinearProgressIndicator(),
          if (state.results.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.23,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: state.results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final place = state.results[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(
                      place.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      vm.selectResult(place);
                    },
                  );
                },
              ),
            ),
          if (state.hasSearched && state.results.isEmpty && state.error == null)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'No places found. Try another city or address, or tap the map.',
              ),
            ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ref
                    .watch(locationPickerCanvasBuilderProvider)
                    .build(
                      viewport: _viewport,
                      onMapCreated: vm.onMapCreated,
                      onStyleLoaded: (_) => vm.onStyleLoaded(),
                      onError: vm.onMapError,
                    ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: IgnorePointer(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Semantics(
                          liveRegion: state.error != null,
                          child: Text(
                            state.error ??
                                (state.isLocating
                                    ? 'Finding your current location…'
                                    : state.mapHasError
                                    ? 'Map could not load. Check your connection, or search for a place.'
                                    : 'Tap the map to drop a pin. Zoom in to place it accurately.'),
                            textAlign: TextAlign.center,
                            style: state.error == null
                                ? null
                                : TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 44,
                  child: FloatingActionButton.small(
                    heroTag: 'picker-current-location',
                    onPressed: state.isLocating ? null : vm.locate,
                    tooltip: 'Use current location',
                    child: state.isLocating
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.selection?.label ?? 'No location selected',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Place the pin where you saw the animal.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: state.canConfirm
                        ? () => Navigator.of(context).pop(vm.confirm())
                        : null,
                    child: const Text('Use this location'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
