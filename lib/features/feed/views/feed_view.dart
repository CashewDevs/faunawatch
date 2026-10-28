import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/feed/views/widgets/feed_post_card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/features/feed/views/widgets/binoculars_icon.dart';

/// The primary Feed screen displaying wildlife sighting posts or an empty state
/// when no posts are available.
class FeedView extends ConsumerWidget {
  const FeedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(feedViewModelProvider);
    if (post != null) {
      return Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            child: FeedPostCard(key: ValueKey(post.id), post: post),
          ),
        ),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Light gray silhouette of binoculars
              BinocularsIcon(
                size: 96,
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFFCBD5E1),
              ),
              const SizedBox(height: 20),

              // Title: "No posts yet."
              Text(
                'No posts yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),

              // Little descriptive sentence
              Text(
                'Sightings and wildlife reports in your community will appear here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
