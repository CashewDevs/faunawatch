import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Bottom typing input bar with a crisp gallery icon button, "Type something"
/// input field, and send button.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.onSend,
    this.onAddImage,
    this.isBusy = false,
    this.hasPhoto = false,
  });

  final Future<bool> Function(String) onSend;
  final VoidCallback? onAddImage;
  final bool isBusy;
  final bool hasPhoto;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (widget.isBusy) return;
    final text = _textController.text.trim();
    if (text.isEmpty && !widget.hasPhoto) return;
    final sent = await widget.onSend(text);
    if (mounted && sent) _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppPaletteColors.of(context);
    final accentColor = isDark
        ? palette.darkAccentBlue
        : palette.messagesHeaderBlue;
    final buttonColor = widget.isBusy
        ? accentColor.withValues(alpha: 0.45)
        : accentColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Crisp gallery / add image button
              Semantics(
                button: true,
                label: 'Add image',
                child: Material(
                  color: isDark
                      ? AppColors.darkBackground
                      : palette.messagesFilterUnselected,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: widget.isBusy ? null : widget.onAddImage,
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 24,
                        color: buttonColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // "Type something" input field
              Expanded(
                child: TextField(
                  enabled: !widget.isBusy,
                  maxLength: 4000,
                  controller: _textController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  cursorColor: accentColor,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type something',
                    counterText: '',
                    hintStyle: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.chatInputHintColor,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Crisp send message button
              Semantics(
                button: true,
                label: 'Send message',
                child: Material(
                  color: accentColor.withValues(
                    alpha: widget.isBusy ? 0.45 : 1.0,
                  ),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: widget.isBusy ? null : _handleSend,
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(
                        Icons.send_rounded,
                        size: 21,
                        color: isDark ? AppColors.darkBackground : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
