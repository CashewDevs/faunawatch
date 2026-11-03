import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import '../models/community_report.dart';

abstract interface class CommunityReportsService {
  Future<List<CommunityReport>> load();
}

class SupabaseCommunityReportsService implements CommunityReportsService {
  const SupabaseCommunityReportsService(this._client);
  final SupabaseClient _client;
  @override
  Future<List<CommunityReport>> load() async {
    final rows = await _client.rpc(
      'community_reports',
      params: {
        'p_min_lat': -90,
        'p_min_lng': -180,
        'p_max_lat': 90,
        'p_max_lng': 180,
      },
    );
    return (rows as List)
        .map((row) => CommunityReport.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }
}

final communityReportsServiceProvider = Provider<CommunityReportsService>(
  (ref) => SupabaseCommunityReportsService(ref.read(supabaseClientProvider)),
);
