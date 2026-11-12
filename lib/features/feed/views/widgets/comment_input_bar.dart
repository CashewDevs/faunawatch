import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:faunawatch/features/feed/models/post_comment.dart';
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

/// Bottom comment composer with an emoji shortcut. Comments are text only.
class CommentInputBar extends StatefulWidget {
  const CommentInputBar({
    super.key,
    required this.avatar,
    required this.onSubmit,
    this.isSending = false,
  });

  final PostAvatar avatar;

  /// Posts the comment and returns whether it succeeded, so a failed post keeps
  /// the user's text.
  final Future<bool> Function(String text) onSubmit;

  /// A comment is being posted; sending is disabled meanwhile.
  final bool isSending;

  @override
  State<CommentInputBar> createState() => _CommentInputBarState();
}

class _CommentInputBarState extends State<CommentInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showEmojis = false;

  bool get _canSend => _controller.text.trim().isNotEmpty && !widget.isSending;

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

  Future<void> _submit() async {
    if (!_canSend) return;
    final posted = await widget.onSubmit(_controller.text);
    if (!posted || !mounted) return;
    _controller.clear();
    setState(() => _showEmojis = false);
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
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(
                                  PostComment.maxLength,
                                ),
                              ],
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
                            icon: Icons.emoji_emotions_outlined,
                            label: 'Add emoji',
                            onTap: () =>
                                setState(() => _showEmojis = !_showEmojis),
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
