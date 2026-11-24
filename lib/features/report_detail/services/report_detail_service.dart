import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/supabase_errors.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';

/// Columns read for one of the signed-in user's own reports (owner RLS lets
/// owners read their own reports, photos and AI analyses in every status).
///
/// `user_notes` and `responder_briefing` are deliberately not read: they are
/// never shown on a post. The exact point is rounded by [FeedPost.fromJson].
const ownReportColumns =
    'id, user_id, status, category, description, user_species, created_at, '
    'place_name, latitude, longitude, '
    'report_images(storage_path, created_at, id), '
    'ai_analyses(status, possible_species, severity, possible_invasive, '
    'visual_condition_assessment, incident_summary, safety_recommendations, '
    'community_warning, created_at, id, species_reference(common_name))';

/// Builds the post for one own-report row read with [ownReportColumns]
/// (photo URLs are not signed yet). The newest completed AI analysis is used.
FeedPost ownReportPost(Map<String, dynamic> row, String userId) {
  final analyses = (row['ai_analyses'] as List?) ?? const [];
  final analysis = analyses
      .cast<Map<String, dynamic>>()
      .where((item) => item['status'] == 'completed')
      .firstOrNull;
  final invasiveMatch = analysis?['species_reference'];
  final photos = (row['report_images'] as List?) ?? const [];
  return FeedPost.fromJson({
    ...row,
    'author_id': userId,
    'author_name': FeedPost.fallbackAuthorName,
    'possible_species': analysis?['possible_species'],
    'severity': analysis?['severity'],
    'possible_invasive': analysis?['possible_invasive'],
    'visual_condition_assessment': analysis?['visual_condition_assessment'],
    'incident_summary': analysis?['incident_summary'],
    'safety_recommendations': analysis?['safety_recommendations'],
    'community_warning': analysis?['community_warning'],
    'invasive_match_name': invasiveMatch is Map
        ? invasiveMatch['common_name']
        : null,
    'photo_paths': [
      for (final photo in photos)
        if (photo['storage_path'] is String) photo['storage_path'],
    ],
  });
}

/// Loads one of the signed-in user's own reports, whatever its status.
abstract interface class ReportDetailService {
  /// The report, or null when it does not exist or is not the user's.
  Future<OwnReport?> fetchOwnReport(String reportId);

  /// The exact point of one of the user's own reports (any status), or null
  /// when it is not theirs. Only for showing the owner their own spot on the
  /// map; never stored or shown to anyone else.
  Future<({double latitude, double longitude})?> fetchOwnLocation(
    String reportId,
  );
}

/// Reads `reports` with its photos and AI analysis, signs the photos for an
/// hour and, for a declined report, adds the admin's reason.
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
    Map<String, dynamic>? row;
    try {
      row = await _fetchRow(reportId, userId, '$ownReportColumns, hidden_at');
    } catch (error) {
      // A database without reports.hidden_at has no hidden posts.
      if (!isMissingColumnError(error, 'hidden_at')) rethrow;
      row = await _fetchRow(reportId, userId, ownReportColumns);
    }
    if (row == null) return null;

    final post = ownReportPost(row, userId);
    final status = ReportStatus.fromDb(row['status'] as String?);
    final (urls, reason) = await (
      Future.wait(post.photoPaths.map(_sign)),
      status == ReportStatus.declined
          ? _declineReason(reportId)
          : Future<DeclineReason?>.value(),
    ).wait;
    return OwnReport(
      post: post.copyWith(photoUrls: [for (final url in urls) ?url]),
      status: status,
      declineReason: reason,
      isHidden: row['hidden_at'] != null,
    );
  }

  Future<Map<String, dynamic>?> _fetchRow(
    String reportId,
    String userId,
    String columns,
  ) => _client
      .from('reports')
      .select(columns)
      .eq('id', reportId)
      .eq('user_id', userId)
      .order('created_at', ascending: true, referencedTable: 'report_images')
      .order('id', ascending: true, referencedTable: 'report_images')
      .order('created_at', ascending: false, referencedTable: 'ai_analyses')
      .order('id', ascending: false, referencedTable: 'ai_analyses')
      .maybeSingle();

  @override
  Future<({double latitude, double longitude})?> fetchOwnLocation(
    String reportId,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sign in to view your report.');
    }
    final row = await _client
        .from('reports')
        .select('latitude, longitude')
        .eq('id', reportId)
        .eq('user_id', userId)
        .maybeSingle();
    final latitude = row?['latitude'], longitude = row?['longitude'];
    if (latitude is! num || longitude is! num) return null;
    return (latitude: latitude.toDouble(), longitude: longitude.toDouble());
  }

  /// The latest decline from `my_report_reviews()`, which returns the
  /// caller's own decisions without the admin, oldest first. A failure only
  /// hides the reason.
  Future<DeclineReason?> _declineReason(String reportId) async {
    try {
      final rows = await _client.rpc(
        'my_report_reviews',
        params: {'p_report_id': reportId},
      );
      final declines = [
        for (final row in rows as List)
          if (row is Map && row['decision'] == 'declined') row,
      ];
      return declines.isEmpty
          ? null
          : DeclineReason.fromDb(declines.last['decline_reason']);
    } catch (_) {
      return null;
    }
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
  @override
  Future<({double latitude, double longitude})?> fetchOwnLocation(
    String reportId,
  ) async => null;
}

/// Replaced on account changes so a pending request cannot show another
/// user's report.
final reportDetailServiceProvider = Provider<ReportDetailService>((ref) {
  if (ref.watch(currentUserIdProvider).valueOrNull == null) {
    return const SignedOutReportDetailService();
  }
  return SupabaseReportDetailService(ref.watch(supabaseClientProvider));
});
