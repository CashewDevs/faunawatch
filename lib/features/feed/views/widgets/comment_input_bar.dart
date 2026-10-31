import 'dart:io';
import 'package:flutter/material.dart';
import 'package:faunawatch/features/feed/views/widgets/post_avatar.dart';

const _quickEmojis = [
  '😀',
  '😍',
  '😮',
  '😢',
  '🙏',
  '👏',
  '🔥',
  '🐾',
  '🐦',
  '🌿',
];

/// Bottom comment composer with photo, emoji, and mention shortcuts.
class CommentInputBar extends StatefulWidget {
  const CommentInputBar({
    super.key,
    required this.avatar,
    required this.onSubmit,
    required this.onPickImage,
    this.replyingTo,
    this.onCancelReply,
  });

  final PostAvatar avatar;

  /// Posts the comment and returns whether it succeeded, so a failed post keeps
  /// the user's text.
  final Future<bool> Function(String text, String? imagePath) onSubmit;
  final Future<String?> Function() onPickImage;

  /// Name of the author being replied to, if any.
  final String? replyingTo;
  final VoidCallback? onCancelReply;

  @override
  State<CommentInputBar> createState() => _CommentInputBarState();
}

class _CommentInputBarState extends State<CommentInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _imagePath;
  bool _showEmojis = false;

  bool get _canSend => _controller.text.trim().isNotEmpty || _imagePath != null;

  @override
  void didUpdateWidget(covariant CommentInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replyingTo != null &&
        widget.replyingTo != oldWidget.replyingTo) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _insert(String text) {
    final value = _controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    _controller.value = TextEditingValue(
      text: value.text.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    _focusNode.requestFocus();
    setState(() {});
  }

  Future<void> _pickImage() async {
    final path = await widget.onPickImage();
    if (path != null && mounted) setState(() => _imagePath = path);
  }

  Future<void> _submit() async {
    if (!_canSend) return;
    final posted = await widget.onSubmit(_controller.text, _imagePath);
    if (!posted || !mounted) return;
    _controller.clear();
    setState(() {
      _imagePath = null;
      _showEmojis = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.replyingTo != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to ${widget.replyingTo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Cancel reply',
                      onPressed: widget.onCancelReply,
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              if (_imagePath != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_imagePath!),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          semanticLabel: 'Selected photo',
                          errorBuilder: (_, _, _) => SizedBox.square(
                            dimension: 72,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Semantics(
                          button: true,
                          label: 'Remove photo',
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: () => setState(() => _imagePath = null),
                            child: const CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_showEmojis)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final emoji in _quickEmojis)
                        GestureDetector(
                          onTap: () => _insert(emoji),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Row(
                children: [
                  widget.avatar,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(left: 16, right: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              minLines: 1,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                hintText: 'Add comment...',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          _InputAction(
                            icon: Icons.image_outlined,
                            label: 'Add photo',
                            onTap: _pickImage,
                          ),
                          _InputAction(
                            icon: Icons.emoji_emotions_outlined,
                            label: 'Add emoji',
                            onTap: () =>
                                setState(() => _showEmojis = !_showEmojis),
                          ),
                          _InputAction(
                            icon: Icons.alternate_email,
                            label: 'Mention someone',
                            onTap: () => _insert('@'),
                          ),
                          if (_canSend)
                            _InputAction(
                              icon: Icons.send_rounded,
                              label: 'Post comment',
                              color: colorScheme.primary,
                              onTap: _submit,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputAction extends StatelessWidget {
  const _InputAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            icon,
            size: 24,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
