import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/services/ai/ai_vision_client.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';

/// The user's pick in the model sheet. A null [modelId] means "use the
/// default".
class AiModelChoice {
  const AiModelChoice(this.modelId);

  final String? modelId;
}

/// Searchable list of [models]. Resolves to null when dismissed.
Future<AiModelChoice?> showAiModelPickerSheet(
  BuildContext context, {
  required AiProvider provider,
  required List<AiModelOption> models,
  required String selected,
  required String defaultModel,
}) {
  return showModalBottomSheet<AiModelChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => _ModelPicker(
        provider: provider,
        models: models,
        selected: selected,
        defaultModel: defaultModel,
        scrollController: controller,
      ),
    ),
  );
}

class _ModelPicker extends StatefulWidget {
  const _ModelPicker({
    required this.provider,
    required this.models,
    required this.selected,
    required this.defaultModel,
    required this.scrollController,
  });

  final AiProvider provider;
  final List<AiModelOption> models;
  final String selected;
  final String defaultModel;
  final ScrollController scrollController;

  @override
  State<_ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<_ModelPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final matches = query.isEmpty
        ? widget.models
        : widget.models
              .where(
                (model) =>
                    model.id.toLowerCase().contains(query) ||
                    model.name.toLowerCase().contains(query),
              )
              .toList();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    Widget check(String id) => id == widget.selected
        ? const Icon(
            Icons.check_circle_rounded,
            color: AppColors.shellHeaderBlue,
          )
        : const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
          child: Text(
            '${widget.provider.displayName} models',
            style: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Pick one that accepts images, then run Test API to check it.',
            style: GoogleFonts.dmSans(fontSize: 12.5, color: muted),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Search models',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            children: [
              if (query.isEmpty)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  title: const Text('Use the default'),
                  subtitle: Text(widget.defaultModel),
                  trailing: check(widget.defaultModel),
                  onTap: () =>
                      Navigator.of(context).pop(const AiModelChoice(null)),
                ),
              if (matches.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    widget.models.isEmpty
                        ? 'No models that accept images were found.'
                        : 'No models match "$_query".',
                    style: TextStyle(color: muted),
                  ),
                ),
              for (final model in matches)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  title: Text(model.name),
                  subtitle: model.name == model.id ? null : Text(model.id),
                  trailing: check(model.id),
                  onTap: () =>
                      Navigator.of(context).pop(AiModelChoice(model.id)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
