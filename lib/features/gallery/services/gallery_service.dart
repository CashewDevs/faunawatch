import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/gallery/models/gallery_filter.dart';
import 'package:faunawatch/features/gallery/models/gallery_post.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads the signed-in user's approved and pending posts, newest submission
/// first. The [GalleryFilter] is applied by the database, so older matches are
/// found too.
abstract interface class GalleryService {
  static const pageSize = 12;
  Future<List<GalleryPost>> fetchPage({
    GalleryFilter filter = const GalleryFilter(),
    FeedPost? before,
  });
}

class SupabaseGalleryService implements GalleryService {
  const SupabaseGalleryService(this._client);
  final SupabaseClient _client;

  static const _statusValues = {
    ReportStatus.pending: 'pending',
    ReportStatus.approved: 'approved',
  };

  @override
  Future<List<GalleryPost>> fetchPage({
    GalleryFilter filter = const GalleryFilter(),
    FeedPost? before,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sign in to view your gallery.');
    }
    var query = _client
        .from('reports')
        .select(
          'id, user_id, status, category, user_species, created_at, '
          'place_name, '
          'report_images(storage_path, created_at, id), '
          'ai_analyses(status, possible_species, created_at, id)',
        )
        .eq('user_id', userId)
        .inFilter('status', [
          for (final status in filter.status.statuses) _statusValues[status]!,
        ]);
    final category = filter.category;
    if (category != null) query = query.eq('category', category.value);
    if (before != null) {
      final time = before.createdAt.toUtc().toIso8601String();
      query = query.or(
        'created_at.lt.$time,and(created_at.eq.$time,id.lt.${before.id})',
      );
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .order('created_at', ascending: true, referencedTable: 'report_images')
        .order('id', ascending: true, referencedTable: 'report_images')
        .order('created_at', ascending: false, referencedTable: 'ai_analyses')
        .order('id', ascending: false, referencedTable: 'ai_analyses')
        .limit(GalleryService.pageSize);
    return Future.wait(
      rows.map((row) async {
        final analyses = (row['ai_analyses'] as List?) ?? const [];
        final analysis = analyses
            .cast<Map<String, dynamic>>()
            .where((item) => item['status'] == 'completed')
            .firstOrNull;
        final photos = (row['report_images'] as List?) ?? const [];
        final post = FeedPost.fromJson({
          ...row,
          'author_id': userId,
          'author_name': FeedPost.fallbackAuthorName,
          'possible_species': analysis?['possible_species'],
          'photo_paths': [
            for (final photo in photos)
              if (photo['storage_path'] is String) photo['storage_path'],
          ],
        });
        final status = ReportStatus.fromDb(row['status'] as String?);
        // Only a thumbnail is needed. If signing fails, try the next photo.
        for (final path in post.photoPaths) {
          try {
            final url = await _client.storage
                .from('report-images')
                .createSignedUrl(path, 3600);
            return GalleryPost(post.copyWith(photoUrls: [url]), status);
          } catch (_) {
            // A missing photo must not prevent the user's other posts loading.
          }
        }
        return GalleryPost(post, status);
      }),
    );
  }
}

class SignedOutGalleryService implements GalleryService {
  const SignedOutGalleryService();
  @override
  Future<List<GalleryPost>> fetchPage({
    GalleryFilter filter = const GalleryFilter(),
    FeedPost? before,
  }) async => const [];
}

/// Replaced on account changes so pending requests cannot restore old cards.
final galleryServiceProvider = Provider<GalleryService>((ref) {
  if (ref.watch(currentUserIdProvider).valueOrNull == null) {
    return const SignedOutGalleryService();
  }
  return SupabaseGalleryService(ref.watch(supabaseClientProvider));
});
