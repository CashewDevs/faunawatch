import 'package:faunawatch/features/profile/models/profile_tag.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_tag_viewmodel.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_tag_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileTagSheet extends ConsumerWidget {
  const ProfileTagSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (_) => const ProfileTagSheet(),
  );

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    ProfileTag? tag,
  ) async {
    final vm = ref.read(profileTagViewModelProvider.notifier);
    final saved = tag == null ? await vm.remove() : await vm.confirm(tag);
    if (context.mounted && saved) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileTagViewModelProvider);
    final current = ref.watch(profileViewModelProvider).valueOrNull?.profileTag;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Your profile tag', style: text.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Close profile tags',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                'Choose a tag that reflects your interests. '
                'You can change or remove it anytime.',
                style: text.bodyMedium,
              ),
              if (current != null) ...[
                const SizedBox(height: 20),
                Text('Currently on your profile', style: text.titleSmall),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ProfileTagBadge(tag: current),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: state.isSaving
                        ? null
                        : () => _save(context, ref, null),
                    child: const Text('Remove tag'),
                  ),
                ),
              ],
              if (state.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  state.errorMessage!,
                  key: const ValueKey('profile_tag_error'),
                  style: text.bodyMedium?.copyWith(color: scheme.error),
                ),
              ],
              const SizedBox(height: 20),
              Text('Choose your tag', style: text.titleMedium),
              for (final tag in state.availableTags) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ProfileTagBadge(tag: tag),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: ValueKey('confirm_profile_tag_${tag.value}'),
                  onPressed: state.isSaving || current == tag
                      ? null
                      : () => _save(context, ref, tag),
                  child: Text(
                    current == tag ? 'Current tag' : 'Use ${tag.label}',
                  ),
                ),
              ],
              if (state.isSaving) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
