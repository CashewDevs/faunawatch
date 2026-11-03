import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/widgets/local_image.dart';
import 'package:faunawatch/features/fauna_lens/views/fauna_lens_view.dart';
import '../models/create_post_state.dart';
import '../models/post_draft.dart';
import '../models/post_location.dart';
import '../viewmodels/create_post_viewmodel.dart';
import 'screens/location_picker_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createPostViewModelProvider);
    final vm = ref.read(createPostViewModelProvider.notifier);
    ref.listen(createPostViewModelProvider, (_, next) => _sync(next));
    _sync(state);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create post')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.paddingOf(context).bottom + 28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: state.submittedId != null
                  ? Column(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'Post submitted',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your report is pending review. Once approved, it can appear on the community map with an approximate location.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: vm.reset,
                          child: const Text('Create another post'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Share a wildlife observation',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add what you saw and where it happened. Stay at a safe distance from wildlife.',
                        ),
                        const SizedBox(height: 20),
                        if (state.photoPath != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              height: 220,
                              child: LocalImage(
                                state.photoPath!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Text('Photo preview unavailable'),
                                ),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: state.isBusy ? null : vm.removePhoto,
                            icon: const Icon(Icons.close),
                            label: const Text('Remove photo'),
                          ),
                        ],
                        Wrap(
                          spacing: 12,
                          children: [
                            OutlinedButton.icon(
                              onPressed: state.isBusy ? null : vm.pickPhoto,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: Text(
                                state.photoPath == null
                                    ? 'Add photo'
                                    : 'Change photo',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: state.isBusy
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => const FaunaLensView(),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Take photo'),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Photo size: 5 MB maximum.'),
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<ReportCategory>(
                          key: ValueKey(state.category),
                          initialValue: state.category,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final category in ReportCategory.values)
                              DropdownMenuItem(
                                value: category,
                                child: Text(
                                  category.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: state.isBusy
                              ? null
                              : (value) => vm.edit(category: value),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _description,
                          enabled: !state.isBusy,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: 'What did you observe?',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => vm.edit(description: value),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _species,
                          enabled: !state.isBusy,
                          decoration: const InputDecoration(
                            labelText: 'Species (optional)',
                            helperText: 'Your identification, if known',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => vm.edit(species: value),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Observation location *',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Search for a place or drop a pin where you saw the animal.',
                        ),
                        const SizedBox(height: 12),
                        Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: Icon(
                              state.hasLocation
                                  ? Icons.location_on
                                  : Icons.add_location_alt_outlined,
                            ),
                            title: Text(
                              state.hasLocation
                                  ? state.locationLabel
                                  : 'Choose observation location',
                            ),
                            subtitle: Text(
                              state.hasLocation
                                  ? 'Location set · Tap to adjust the pin'
                                  : 'Required to show your report on the map',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            enabled: !state.isBusy,
                            onTap: state.isBusy ? null : _pickLocation,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: state.isBusy ? null : vm.locate,
                            icon: const Icon(Icons.my_location),
                            label: const Text('Use current location'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _notes,
                          enabled: !state.isBusy,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Additional notes (optional)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => vm.edit(notes: value),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Posts are reviewed before appearing on the community map. Shared coordinates are approximate. AI analysis is currently unavailable.',
                        ),
                        if (state.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                state.error!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        if (state.isBusy) const LinearProgressIndicator(),
                        FilledButton.icon(
                          onPressed: state.canSubmit ? vm.submit : null,
                          icon: const Icon(Icons.send_outlined),
                          label: Text(
                            state.isBusy ? 'Please wait…' : 'Submit post',
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
