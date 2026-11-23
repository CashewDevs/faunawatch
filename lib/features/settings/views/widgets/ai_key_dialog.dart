import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/views/widgets/ai_settings_style.dart';

/// Shows the small pop-up for adding, replacing or removing one AI key.
///
/// [onSave] gets the typed key and returns whether it was saved (it shows the
/// AI Keys Agreement first, so it may be declined). The pop-up closes only on
/// success, so a declined or failed save keeps the typed key. [onRemove] is
/// offered only when [hasKey]; null hides it.
Future<void> showAiKeyDialog(
  BuildContext context, {
  required AiProvider provider,
  required bool hasKey,
  required Future<bool> Function(String apiKey) onSave,
  required VoidCallback onGetKey,
  Future<bool> Function()? onRemove,
  String? title,
  String? note,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => AiKeyDialog(
      provider: provider,
      hasKey: hasKey,
      onSave: onSave,
      onGetKey: onGetKey,
      onRemove: onRemove,
      title: title,
      note: note,
    ),
  );
}

class AiKeyDialog extends StatefulWidget {
  const AiKeyDialog({
    super.key,
    required this.provider,
    required this.hasKey,
    required this.onSave,
    required this.onGetKey,
    this.onRemove,
    this.title,
    this.note,
  });

  final AiProvider provider;
  final bool hasKey;
  final Future<bool> Function(String apiKey) onSave;
  final VoidCallback onGetKey;
  final Future<bool> Function()? onRemove;

  /// Defaults to the provider's name followed by "API key".
  final String? title;

  /// An optional line above the field, e.g. what saving will replace.
  final String? note;

  @override
  State<AiKeyDialog> createState() => _AiKeyDialogState();
}

class _AiKeyDialogState extends State<AiKeyDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave => !_busy && _controller.text.trim().isNotEmpty;

  /// Runs [action] (save or remove) and closes the pop-up if it succeeded.
  Future<void> _run(Future<bool> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final done = await action();
    if (!mounted) return;
    if (done) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  void _save() {
    if (_canSave) _run(() => widget.onSave(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final style = AiSettingsStyle.of(context);
    final name = widget.provider.displayName;
    final onRemove = widget.hasKey ? widget.onRemove : null;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: style.border, width: 1.2),
    );

    final cancelAndSave = [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: Text(
          'Cancel',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
      ),
      FilledButton(
        onPressed: _canSave ? _save : null,
        style: FilledButton.styleFrom(
          backgroundColor: style.accent,
          foregroundColor: Colors.white,
        ),
        child: Text(
          'Save',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
      ),
    ];

    return AlertDialog(
      backgroundColor: style.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: Icon(Icons.key_rounded, color: style.accent, size: 28),
      title: Text(
        widget.title ?? '$name API key',
        style: GoogleFonts.dmSans(
          color: style.title,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.note != null) ...[
              Text(
                widget.note!,
                style: GoogleFonts.dmSans(
                  color: style.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _controller,
              enabled: !_busy,
              autofocus: true,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
              style: GoogleFonts.dmSans(color: style.title, fontSize: 15),
              decoration: InputDecoration(
                labelText: 'API key',
                labelStyle: GoogleFonts.dmSans(color: style.muted),
                floatingLabelStyle: GoogleFonts.dmSans(
                  color: style.accent,
                  fontWeight: FontWeight.w700,
                ),
                // A saved key is never read back, so the field starts empty.
                hintText: widget.provider.keyHint,
                hintStyle: GoogleFonts.dmSans(color: style.muted),
                helperText: widget.hasKey
                    ? 'A key is saved. Paste a new one to replace it.'
                    : null,
                helperMaxLines: 2,
                helperStyle: GoogleFonts.dmSans(color: style.muted),
                border: fieldBorder,
                enabledBorder: fieldBorder,
                disabledBorder: fieldBorder,
                focusedBorder: fieldBorder.copyWith(
                  borderSide: BorderSide(color: style.accent, width: 1.6),
                ),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show API key' : 'Hide API key',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: style.muted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: widget.onGetKey,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Where do I get a $name key?',
                        style: GoogleFonts.dmSans(
                          color: style.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.north_east_rounded,
                      size: 14,
                      color: style.accent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: onRemove == null
          ? MainAxisAlignment.end
          : MainAxisAlignment.spaceBetween,
      actions: [
        if (onRemove != null)
          TextButton(
            onPressed: _busy ? null : () => _run(onRemove),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.signOutButtonRed,
            ),
            child: Text(
              'Remove',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
            ),
          ),
        if (onRemove == null)
          ...cancelAndSave
        else
          Row(mainAxisSize: MainAxisSize.min, children: cancelAndSave),
      ],
    );
  }
}
