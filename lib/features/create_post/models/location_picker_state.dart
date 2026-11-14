import 'post_location.dart';

class LocationPickerState {
  const LocationPickerState({
    this.selection,
    this.query = '',
    this.results = const [],
    this.isSearching = false,
    this.isLocating = false,
    this.hasSearched = false,
    this.error,
    this.mapHasError = false,
    this.isDarkMode = false,
  });
  final PostLocation? selection;
  final String query;
  final List<PostLocation> results;
  final bool isSearching, isLocating, hasSearched, mapHasError;
  final bool isDarkMode;
  final String? error;

  bool get canConfirm => selection?.isValid == true && !isLocating;

  LocationPickerState copyWith({
    PostLocation? selection,
    String? query,
    List<PostLocation>? results,
    bool? isSearching,
    bool? isLocating,
    bool? hasSearched,
    String? error,
    bool? mapHasError,
    bool? isDarkMode,
  }) => LocationPickerState(
    selection: selection ?? this.selection,
    query: query ?? this.query,
    results: results ?? this.results,
    isSearching: isSearching ?? this.isSearching,
    isLocating: isLocating ?? this.isLocating,
    hasSearched: hasSearched ?? this.hasSearched,
    error: error,
    mapHasError: mapHasError ?? this.mapHasError,
    isDarkMode: isDarkMode ?? this.isDarkMode,
  );
}
