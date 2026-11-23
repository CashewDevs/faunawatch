import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';
import 'package:faunawatch/features/messages/viewmodels/new_chat_viewmodel.dart';
import 'package:faunawatch/features/messages/views/widgets/chat_user_avatar.dart';

/// Screen for searching registered community users and starting a private chat.
class NewChatView extends ConsumerStatefulWidget {
  const NewChatView({super.key});

  @override
  ConsumerState<NewChatView> createState() => _NewChatViewState();
}

class _NewChatViewState extends ConsumerState<NewChatView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newChatViewModelProvider);
    final vm = ref.read(newChatViewModelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppPaletteColors.of(context);
    final headerBg = isDark
        ? palette.darkHeaderGradientStart
        : palette.searchHeaderBackground;
    final accentColor = isDark
        ? palette.darkAccentBlue
        : palette.messagesHeaderBlue;
    final fieldBg = isDark ? AppColors.darkBackground : Colors.white;
    final fieldBorder = isDark
        ? AppColors.darkBorder
        : palette.searchFieldStroke;
    final mutedText = isDark
        ? AppColors.darkTextSecondary
        : const Color(0xFF6B7C8F);
    final headingColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.loginDarkText;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rounded light-blue header with back button, centered title, and search pill
            Container(
              decoration: BoxDecoration(
                color: headerBg,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Semantics(
                            button: true,
                            label: 'Back',
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: Icon(
                                  Icons.chevron_left_rounded,
                                  color: accentColor,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'New Chat',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 36),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(left: 10, bottom: 6),
                        child: Text(
                          'Search by username or name',
                          style: GoogleFonts.dmSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: mutedText,
                          ),
                        ),
                      ),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: fieldBg,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: fieldBorder, width: 1.3),
                        ),
                        padding: const EdgeInsets.only(left: 4, right: 14),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Search users',
                              visualDensity: VisualDensity.compact,
                              onPressed: state.openingUserId == null
                                  ? () => vm.search(_controller.text)
                                  : null,
                              icon: Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: accentColor,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                textInputAction: TextInputAction.search,
                                onSubmitted: vm.search,
                                onChanged: vm.onQueryChanged,
                                enabled: state.openingUserId == null,
                                cursorColor: accentColor,
                                style: GoogleFonts.dmSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Type here...',
                                  hintStyle: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF94A3B8),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  state.error!,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkErrorText : Colors.red,
                  ),
                ),
              ),
            if (state.isSearching)
              LinearProgressIndicator(
                minHeight: 2.5,
                color: accentColor,
                backgroundColor: accentColor.withValues(alpha: 0.15),
              ),
            Expanded(
              child: state.users.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Double-ringed yellow & white circle badge
                            Container(
                              width: 112,
                              height: 112,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? palette.darkFilterSelected
                                    : const Color(0xFFFFF4C3),
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? AppColors.darkSurface
                                      : Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFFF5C842),
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.person_add_alt_1_outlined,
                                  size: 32,
                                  color: accentColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              state.isSearching
                                  ? 'Finding matching people…'
                                  : state.hasSearched
                                  ? 'No users found'
                                  : 'Find someone to chat with',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: headingColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              state.isSearching
                                  ? 'Please wait a moment.'
                                  : state.hasSearched
                                  ? 'No users found.'
                                  : 'Type at least two characters to see matching people.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                fontSize: 13.5,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                color: mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: state.users.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 72,
                        endIndent: 16,
                        color: isDark
                            ? AppColors.darkBorder
                            : const Color(0xFFE2E8F0),
                      ),
                      itemBuilder: (context, index) {
                        final user = state.users[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 4,
                          ),
                          title: Text(
                            user.name,
                            style: GoogleFonts.dmSans(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: headingColor,
                            ),
                          ),
                          leading: ChatUserAvatar(user: user),
                          trailing: state.openingUserId == user.id
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: accentColor,
                                  ),
                                )
                              : Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: accentColor,
                                ),
                          enabled: state.openingUserId == null,
                          onTap: () async {
                            final thread = await vm.open(user);
                            if (context.mounted && thread != null) {
                              Navigator.of(context).pop<MessageThread>(thread);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
