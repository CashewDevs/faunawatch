import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Bottom typing input bar with add image button (`addIM.webp`),
/// "Type something" input, and send message button (`sendM.webp`).
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
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Add Image Icon: addIM.webp
              Semantics(
                button: true,
                label: 'Add image',
                child: GestureDetector(
                  onTap: widget.isBusy ? null : widget.onAddImage,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.asset(
                      AppAssets.addImageIcon,
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 34,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.chatInputHintColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // "Type something" input field
              Expanded(
                child: TextField(
                  enabled: !widget.isBusy,
                  maxLength: 4000,
                  controller: _textController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  cursorColor: isDark
                      ? AppPaletteColors.of(context).darkAccentBlue
                      : AppPaletteColors.of(context).messagesHeaderBlue,
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
              const SizedBox(width: 14),

              // Send Message Icon: sendM.webp
              Semantics(
                button: true,
                label: 'Send message',
                child: GestureDetector(
                  onTap: widget.isBusy ? null : _handleSend,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.asset(
                      AppAssets.sendMessageIcon,
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                      color: isDark
                          ? AppPaletteColors.of(context).darkAccentBlue
                          : null,
                      colorBlendMode: isDark ? BlendMode.srcIn : null,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.send_rounded,
                        size: 32,
                        color: isDark
                            ? AppPaletteColors.of(context).darkAccentBlue
                            : AppPaletteColors.of(context).messagesHeaderBlue,
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
