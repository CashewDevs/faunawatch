import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/viewmodels/ai_key_settings_viewmodel.dart';

class AiKeySettingsView extends ConsumerStatefulWidget {
  const AiKeySettingsView({super.key});

  @override
  ConsumerState<AiKeySettingsView> createState() =>
      _AiKeySettingsViewState();
}

class _AiKeySettingsViewState extends ConsumerState<AiKeySettingsView> {
  final _apiKeyController = TextEditingController();
  bool _obscureApiKey = true;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(aiKeySettingsViewModelProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const Center(
        child: Text('Could not load secure key settings.'),
      ),
      data: (settings) => _buildSettings(context, settings),
    );
  }

  Widget _buildSettings(BuildContext context, AiKeySettingsState settings) {
    final viewModel = ref.read(aiKeySettingsViewModelProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'AI provider keys',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Keys are stored securely on this device and are not sent to FaunaWatch.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<AiProvider>(
          key: ValueKey(settings.selectedProvider),
          initialValue: settings.selectedProvider,
          decoration: const InputDecoration(labelText: 'AI provider'),
          items: AiProvider.values
              .map(
                (provider) => DropdownMenuItem(
                  value: provider,
                  child: Text(provider.displayName),
                ),
              )
              .toList(),
          onChanged: settings.isSaving
              ? null
              : (provider) {
                  if (provider == null) return;
                  _apiKeyController.clear();
                  viewModel.selectProvider(provider);
                },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _apiKeyController,
          obscureText: _obscureApiKey,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'API key',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _obscureApiKey ? 'Show API key' : 'Hide API key',
              icon: Icon(
                _obscureApiKey ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () => setState(() {
                _obscureApiKey = !_obscureApiKey;
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          settings.selectedProviderIsConfigured
              ? 'A key is saved securely for ${settings.selectedProvider.displayName}.'
              : 'No key is saved for ${settings.selectedProvider.displayName}.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (settings.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            settings.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: settings.isSaving || _apiKeyController.text.trim().isEmpty
              ? null
              : () async {
                  final saved = await viewModel.saveKey(_apiKeyController.text);
                  if (saved && mounted) {
                    setState(_apiKeyController.clear);
                  }
                },
          icon: settings.isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(settings.isSaving ? 'Saving' : 'Save key'),
        ),
        if (settings.selectedProviderIsConfigured) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: settings.isSaving
                ? null
                : () async {
                    final removed = await viewModel.removeKey();
                    if (removed && mounted) {
                      setState(_apiKeyController.clear);
                    }
                  },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove saved key'),
          ),
        ],
      ],
    );
  }
}