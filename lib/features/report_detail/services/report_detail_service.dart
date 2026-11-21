import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';

/// Loads one of the signed-in user's own reports, whatever its status.
abstract interface class ReportDetailService {
  /// The report, or null when it does not exist or is not the user's.
  Future<OwnReport?> fetchOwnReport(String reportId);
}

/// Reads `reports` (owner RLS lets owners read their own reports in every
/// status) with its photos and AI analysis, and signs the photos for an hour.
class SupabaseReportDetailService implements ReportDetailService {
  const SupabaseReportDetailService(this._client);
  final SupabaseClient _client;

  static const _urlLifetimeSeconds = 3600;

  @override
  Future<OwnReport?> fetchOwnReport(String reportId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sign in to view your report.');
    }
    final row = await _client
        .from('reports')
        .select(
          'id, user_id, category, description, user_species, status, '
          'created_at, place_name, '
          'report_images(storage_path, created_at, id), '
          'ai_analyses(status, possible_species, created_at, id)',
        )
        .eq('id', reportId)
        .eq('user_id', userId)
        .order('created_at', ascending: true, referencedTable: 'report_images')
        .order('id', ascending: true, referencedTable: 'report_images')
        .order('created_at', ascending: false, referencedTable: 'ai_analyses')
        .order('id', ascending: false, referencedTable: 'ai_analyses')
        .maybeSingle();
    if (row == null) return null;

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
    final urls = await Future.wait(post.photoPaths.map(_sign));
    return OwnReport(
      post: post.copyWith(photoUrls: [for (final url in urls) ?url]),
      status: ReportStatus.fromDb(row['status'] as String?),
    );
  }

  /// A photo that cannot be signed is left out rather than failing the load.
  Future<String?> _sign(String path) async {
    try {
      return await _client.storage
          .from('report-images')
          .createSignedUrl(path, _urlLifetimeSeconds);
    } catch (_) {
      return null;
    }
  }
}

class SignedOutReportDetailService implements ReportDetailService {
  const SignedOutReportDetailService();
  @override
  Future<OwnReport?> fetchOwnReport(String reportId) async => null;
}

/// Replaced on account changes so a pending request cannot show another
/// user's report.
final reportDetailServiceProvider = Provider<ReportDetailService>((ref) {
  if (ref.watch(currentUserIdProvider).valueOrNull == null) {
    return const SignedOutReportDetailService();
  }
  return SupabaseReportDetailService(ref.watch(supabaseClientProvider));
});
