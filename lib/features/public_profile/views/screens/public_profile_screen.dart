import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/gallery/models/gallery_filter.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_card.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_header.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_load_more.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_skeleton.dart';
import 'package:faunawatch/features/messages/views/chat_conversation_view.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_header_card.dart';
import 'package:faunawatch/features/public_profile/viewmodels/public_profile_viewmodel.dart';
import 'package:faunawatch/features/public_profile/views/screens/public_gallery_post_viewer.dart';
import 'package:faunawatch/features/suspension/models/account_suspension.dart';
import 'package:faunawatch/features/suspension/views/widgets/suspension_notices.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// An account's public identity and approved gallery, independent of My Gallery.
class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId});
  final String userId;

  Future<void> _openMessage(
    BuildContext context,
    WidgetRef ref,
    PublicProfileViewModel vm,
  ) async {
    if (blockedBySuspension(context, ref, SuspendedAction.message)) return;
    final thread = await vm.openPrivateChat();
    if (!context.mounted || thread == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ChatConversationView(thread: thread)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = publicProfileViewModelProvider(userId);
    final state = ref.watch(provider);
    final vm = ref.read(provider.notifier);
    final colors = AppPaletteColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = state.profile;
    final viewerId = ref.watch(currentUserIdProvider).valueOrNull;
    final signedIn = viewerId != null;
    final canMessage = ref.watch(canMessageProvider(userId));
    final items = vm.items;
    final postsHidden = vm.postsHidden;
    ref.listen(provider.select((state) => state.message), (_, message) {
      if (message == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      vm.clearMessage();
    });

    Widget withFloatingBack(Widget child) => Stack(
      children: [
        child,
        Positioned(
          top: 8,
          left: 12,
          child: SafeArea(
            bottom: false,
            child: Tooltip(
              message: 'Back',
              child: Material(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.92),
                elevation: 2,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Back',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.3, 1],
            colors: isDark
                ? [
                    colors.darkProfileGradientStart,
                    colors.darkProfileGradientEnd,
                  ]
                : [
                    colors.profileBackgroundGradientStart,
                    colors.profileBackgroundGradientEnd,
                  ],
          ),
        ),
        child: !signedIn
            ? withFloatingBack(
                const _ProfileNotice(title: 'Sign in to view this profile.'),
              )
            : state.isLoading
            ? withFloatingBack(const Center(child: CircularProgressIndicator()))
            : profile == null
            ? withFloatingBack(
                _ProfileNotice(
                  title: state.hasError
                      ? 'Could not load this profile.'
                      : 'This profile is no longer available.',
                  onRetry: state.hasError ? vm.refresh : null,
                ),
              )
            : RefreshIndicator(
                onRefresh: vm.refresh,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification &&
                        (notification.scrollDelta ?? 0) > 0 &&
                        notification.metrics.extentAfter < 300) {
                      vm.loadMore();
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    key: PageStorageKey('public-profile-$userId'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: ProfileHeaderCard(
                          profile: profile.username.isEmpty
                              ? profile.copyWith(
                                  username: FeedPost.fallbackAuthorName,
                                )
                              : profile,
                          onBack: () => Navigator.of(context).maybePop(),
                          onMessage: canMessage
                              ? () => _openMessage(context, ref, vm)
                              : null,
                          isOpeningMessage: state.isOpeningChat,
                        ),
                      ),
                      // A private account shows a notice instead of its
                      // gallery and category filters.
                      if (!postsHidden)
                        SliverToBoxAdapter(
                          child: GalleryHeader(
                            title: 'Public Gallery',
                            filter: GalleryFilter(
                              status: GalleryStatusFilter.approved,
                              category: state.category,
                            ),
                            onCategorySelected: vm.setCategory,
                          ),
                        ),
                      if (postsHidden)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _ProfileNotice(
                            key: const ValueKey('public_profile_posts_private'),
                            icon: Icons.lock_outline_rounded,
                            title: "This account's posts are private",
                            hint: canMessage
                                ? 'You can still send them a message.'
                                : null,
                          ),
                        )
                      else if (state.isLoadingPosts)
                        const GallerySkeleton()
                      else if (state.postsHaveError || items.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _ProfileNotice(
                            title: state.postsHaveError
                                ? 'Could not load this gallery.'
                                : state.category != null
                                ? 'No posts in this category.'
                                : 'No public posts yet.',
                            hint: state.postsHaveError
                                ? 'Check your connection and try again.'
                                : state.category != null
                                ? 'Try another filter.'
                                : 'Approved wildlife reports will appear here.',
                            onRetry: state.postsHaveError
                                ? vm.retryPosts
                                : null,
                          ),
                        )
                      else ...[
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          sliver: SliverGrid.builder(
                            gridDelegate: galleryGridDelegate,
                            itemCount: items.length,
                            itemBuilder: (context, index) => GalleryCard(
                              key: ValueKey(items[index].id),
                              item: items[index],
                              onTap: () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => PublicGalleryPostViewer(
                                    userId: userId,
                                    initialPostId: items[index].id,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: state.hasMore
                                  ? GalleryLoadMore(
                                      isLoading: state.isLoadingMore,
                                      onLoad: vm.loadMore,
                                    )
                                  : const SizedBox(height: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _ProfileNotice extends StatelessWidget {
  const _ProfileNotice({
    super.key,
    required this.title,
    this.hint,
    this.onRetry,
    this.icon,
  });
  final String title;
  final String? hint;
  final VoidCallback? onRetry;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 14),
            ),
          ],
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
