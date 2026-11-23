import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final isDark = theme.brightness == Brightness.dark;
    final headerBg = isDark
        ? AppColors.darkSurface
        : AppColors.searchHeaderBackground;
    final accentBlue = isDark
        ? AppColors.darkAccentBlue
        : AppColors.searchHeaderBlue;
    final fieldFill = isDark ? AppColors.darkBackground : Colors.white;
    final fieldBorder = isDark
        ? AppColors.darkBorder
        : AppColors.searchFieldStroke;
    final surfaceCard = isDark ? AppColors.darkSurface : Colors.white;
    final hintColor = isDark
        ? AppColors.darkTextSecondary
        : const Color(0xFF7B8794);
    final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryText = isDark
        ? AppColors.darkTextSecondary
        : const Color(0xFF334155);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: Column(
        children: [
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
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Rounded light-blue header card with back chevron, title, and pill search bar
                      Container(
                        key: const ValueKey('location_picker_header'),
                        decoration: BoxDecoration(
                          color: headerBg,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(28),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.25 : 0.08,
                              ),
                              offset: const Offset(0, 3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Back',
                                      onPressed: () =>
                                          Navigator.of(context).maybePop(),
                                      icon: Icon(
                                        Icons.chevron_left_rounded,
                                        color: accentBlue,
                                        size: 32,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Choose Observation Location',
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.dmSans(
                                          color: accentBlue,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 40),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: TextField(
                                    controller: _query,
                                    textInputAction: TextInputAction.search,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500,
                                      color: primaryText,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Search city or address',
                                      hintStyle: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: hintColor,
                                      ),
                                      filled: true,
                                      fillColor: fieldFill,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 11,
                                          ),
                                      prefixIcon: Icon(
                                        Icons.search_rounded,
                                        color: accentBlue,
                                        size: 22,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(28),
                                        borderSide: BorderSide(
                                          color: fieldBorder,
                                          width: 1.2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(28),
                                        borderSide: BorderSide(
                                          color: fieldBorder,
                                          width: 1.2,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(28),
                                        borderSide: BorderSide(
                                          color: accentBlue,
                                          width: 1.6,
                                        ),
                                      ),
                                      suffixIcon: IconButton(
                                        tooltip: 'Search places',
                                        onPressed: state.isSearching
                                            ? null
                                            : () {
                                                FocusScope.of(
                                                  context,
                                                ).unfocus();
                                                vm.search();
                                              },
                                        icon: Icon(
                                          Icons.login_rounded,
                                          color: accentBlue,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                    onChanged: vm.updateQuery,
                                    onSubmitted: (_) {
                                      FocusScope.of(context).unfocus();
                                      vm.search();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (state.isSearching) const LinearProgressIndicator(),
                      if (state.results.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Material(
                            color: surfaceCard,
                            elevation: 4,
                            borderRadius: BorderRadius.circular(18),
                            clipBehavior: Clip.antiAlias,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.sizeOf(context).height * 0.23,
                              ),
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: state.results.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final place = state.results[index];
                                  return ListTile(
                                    leading: Icon(
                                      Icons.location_on_outlined,
                                      color: accentBlue,
                                    ),
                                    title: Text(
                                      place.label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: primaryText,
                                      ),
                                    ),
                                    onTap: () {
                                      FocusScope.of(context).unfocus();
                                      vm.selectResult(place);
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      if (state.hasSearched &&
                          state.results.isEmpty &&
                          state.error == null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Material(
                            color: surfaceCard,
                            elevation: 2,
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Text(
                                'No places found. Try another city or address, or tap the map.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: secondaryText,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (state.error != null ||
                          state.isLocating ||
                          state.mapHasError)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                          child: IgnorePointer(
                            child: Material(
                              color: surfaceCard.withValues(alpha: 0.94),
                              elevation: 2,
                              borderRadius: BorderRadius.circular(16),
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
                                            : 'Map could not load. Check your connection, or search for a place.'),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      color: state.error == null
                                          ? primaryText
                                          : theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'picker-current-location',
                    backgroundColor: isDark
                        ? AppColors.darkSurface
                        : Colors.white,
                    foregroundColor: accentBlue,
                    onPressed: state.isLocating ? null : vm.locate,
                    tooltip: 'Use current location',
                    child: state.isLocating
                        ? SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accentBlue,
                            ),
                          )
                        : const Icon(Icons.my_location_rounded),
                  ),
                ),
              ],
            ),
          ),
          // Bottom light-blue panel matching the header with pin label + gradient CTA
          Container(
            key: const ValueKey('location_picker_bottom_bar'),
            color: headerBg,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on, size: 22, color: accentBlue),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 4,
                          child: Text(
                            state.selection?.label ?? 'No location selected',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: primaryText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 6,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Place the pin where you saw the animal',
                              maxLines: 1,
                              softWrap: false,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: secondaryText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: DecoratedBox(
                        key: const ValueKey('location_picker_confirm_box'),
                        decoration: state.canConfirm
                            ? BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    AppColors.onboardingButtonGradientStart,
                                    AppColors.onboardingButtonGradientEnd,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: accentBlue,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.14),
                                    offset: const Offset(0, 3),
                                    blurRadius: 8,
                                  ),
                                ],
                              )
                            : const BoxDecoration(),
                        child: FilledButton(
                          onPressed: state.canConfirm
                              ? () => Navigator.of(context).pop(vm.confirm())
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: state.canConfirm
                                ? Colors.transparent
                                : null,
                            foregroundColor: state.canConfirm
                                ? const Color(0xFF003E43)
                                : null,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            textStyle: GoogleFonts.dmSans(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: const Text('Use this location'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
