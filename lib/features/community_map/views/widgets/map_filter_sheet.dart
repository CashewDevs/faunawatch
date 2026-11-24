import 'package:faunawatch/features/community_map/models/map_pin_filter.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:flutter/material.dart';

/// Lets the user tick categories, then species within them, to choose which
/// posts the map shows as pins.
///
/// The ticks stay a draft until Show is tapped, which closes the sheet with
/// the new filter; closing it any other way keeps the old one. The lists and
/// counts come from [choices], taken from the map's view model when the
/// sheet opens.
class MapFilterSheet extends StatefulWidget {
  const MapFilterSheet({
    super.key,
    required this.initial,
    required this.choices,
  });

  final MapPinFilter initial;
  final MapFilterChoices choices;

  /// Above this many species, a search box helps find one.
  static const searchFrom = 8;

  @override
  State<MapFilterSheet> createState() => _MapFilterSheetState();
}

class _MapFilterSheetState extends State<MapFilterSheet> {
  late Set<ReportCategory> _categories = {...widget.initial.categories};
  late Set<String> _species = {...widget.initial.species};
  final _search = TextEditingController();

  MapPinFilter get _draft =>
      MapPinFilter(categories: _categories, species: _species);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleCategory(ReportCategory category, bool on) => setState(() {
    _categories = {..._categories};
    on ? _categories.add(category) : _categories.remove(category);
  });

  void _toggleSpecies(String key, bool on) => setState(() {
    _species = {..._species};
    on ? _species.add(key) : _species.remove(key);
  });

  void _clear() => setState(() {
    _categories = {};
    _species = {};
    _search.clear();
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = widget.choices.speciesFor(_categories, ticked: _species);
    final query = _search.text.trim().toLowerCase();
    final shownOptions = query.isEmpty
        ? options
        : options.where((o) => o.label.toLowerCase().contains(query)).toList();
    final matching = widget.choices.countMatching(_draft);
    // Nothing ticked always works, even with no posts loaded, so a filter
    // can be removed at any time.
    final showsAll = !_draft.isActive;
    final hint = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Filter pins',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: _draft.isActive ? _clear : null,
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'FaunaGuard still warns you about every post, even hidden ones.',
            style: hint,
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              const _SectionTitle('Category'),
              for (final category in ReportCategory.values)
                _CountedCheckbox(
                  label: category.label,
                  count: widget.choices.categoryCounts[category] ?? 0,
                  value: _categories.contains(category),
                  onChanged: (on) => _toggleCategory(category, on),
                ),
              const _SectionTitle('Species'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  _categories.isEmpty
                      ? "The AI's best guess for each post."
                      : "The AI's best guess, in the ticked categories.",
                  style: hint,
                ),
              ),
              if (options.length > MapFilterSheet.searchFrom)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search species',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (shownOptions.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text(
                    options.isEmpty
                        ? 'No posts to pick a species from.'
                        : 'No species match "${_search.text.trim()}".',
                    style: hint,
                  ),
                ),
              for (final option in shownOptions)
                _CountedCheckbox(
                  key: ValueKey('species-${option.key}'),
                  label: option.label,
                  count: option.count,
                  value: _species.contains(option.key),
                  italic: option.isUnknown,
                  onChanged: (on) => _toggleSpecies(option.key, on),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: showsAll || matching > 0
                ? () => Navigator.of(context).pop(_draft)
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(switch (matching) {
              _ when showsAll => 'Show all posts',
              0 => 'No posts match',
              1 => 'Show 1 post',
              _ => 'Show $matching posts',
            }),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

/// A tick box row with the number of posts it covers at the end.
class _CountedCheckbox extends StatelessWidget {
  const _CountedCheckbox({
    super.key,
    required this.label,
    required this.count,
    required this.value,
    required this.onChanged,
    this.italic = false,
  });

  final String label;
  final int count;
  final bool value, italic;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CheckboxListTile(
      value: value,
      onChanged: (on) => onChanged(on ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      title: Text(
        label,
        style: italic ? const TextStyle(fontStyle: FontStyle.italic) : null,
      ),
      secondary: Semantics(
        label: count == 1 ? '1 post' : '$count posts',
        excludeSemantics: true,
        child: Text(
          '$count',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
