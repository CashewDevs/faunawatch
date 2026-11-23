import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/messages/views/chat_conversation_view.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_header_card.dart';
import 'package:faunawatch/features/public_profile/viewmodels/profile_preview_viewmodel.dart';
import 'package:faunawatch/features/public_profile/viewmodels/public_profile_viewmodel.dart';
import 'package:faunawatch/features/public_profile/views/screens/public_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// A quick look at another account, opened from a post's author on the Feed
/// or the map: banner, picture, name and bio, a Message button, and a
/// "View full profile" button that opens [PublicProfileScreen] with their
/// posts. Both buttons close the sheet first, so Back returns to the post.
class ProfilePreviewSheet extends ConsumerWidget {
  const ProfilePreviewSheet({super.key, required this.userId});
  final String userId;

  /// Slides the preview of [userId] up over [context]'s screen.
  static Future<void> show(BuildContext context, String userId) async {
    if (userId.trim().isEmpty) return;
    final colors = AppPaletteColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      backgroundColor: isDark
          ? colors.darkProfileGradientStart
          : colors.profileBackgroundGradientStart,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      builder: (_) => ProfilePreviewSheet(userId: userId),
    );
  }

  Future<void> _openMessage(
    BuildContext context,
    ProfilePreviewViewModel vm,
  ) async {
    final navigator = Navigator.of(context);
    final thread = await vm.openPrivateChat();
    if (!context.mounted || thread == null) return;
    navigator.pop();
    await navigator.push<void>(
      MaterialPageRoute(builder: (_) => ChatConversationView(thread: thread)),
    );
  }

  Future<void> _openFullProfile(BuildContext context) async {
    final navigator = Navigator.of(context);
    navigator.pop();
    await navigator.push<void>(
      MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: userId)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = profilePreviewViewModelProvider(userId);
    final state = ref.watch(provider);
    final vm = ref.read(provider.notifier);
    final signedIn = ref.watch(currentUserIdProvider).valueOrNull != null;
    final canMessage = ref.watch(canMessageProvider(userId));
    final profile = state.profile;

    if (!signedIn) {
      return const _PreviewNotice(title: 'Sign in to view this profile.');
    }
    if (state.isLoading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (profile == null) {
      return _PreviewNotice(
        title: state.hasError
            ? 'Could not load this profile.'
            : 'This profile is no longer available.',
        onRetry: state.hasError ? vm.retry : null,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.darkAccentBlue : const Color(0xFF1A5DC9);
    return SingleChildScrollView(
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileHeaderCard(
              profile: profile.username.isEmpty
                  ? profile.copyWith(username: FeedPost.fallbackAuthorName)
                  : profile,
              onMessage: canMessage ? () => _openMessage(context, vm) : null,
              isOpeningMessage: state.isOpeningChat,
            ),
            if (state.message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  state.message!,
                  key: const ValueKey('profile_preview_error'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: OutlinedButton.icon(
                key: const ValueKey('profile_preview_full_profile'),
                onPressed: () => _openFullProfile(context),
                icon: const Icon(Icons.person_outline_rounded),
                label: Text(
                  'View full profile',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent, width: 1.3),
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice({required this.title, this.onRetry});
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    ),
  );
}
