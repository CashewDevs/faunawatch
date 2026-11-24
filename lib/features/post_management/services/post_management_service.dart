import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/post_management/models/own_post_menu.dart';

export 'package:faunawatch/features/post_management/models/own_post_menu.dart'
    show PostActionException, PostActionFailure;

/// Hides, shows and deletes the signed-in user's own posts. The database
/// checks that the post is theirs (see
/// `20261124170000_add_edit_hide_delete_posts.sql`).
abstract interface class PostManagementService {
  /// Hides an approved post from everyone but the user and admins, or shows
  /// it again.
  Future<void> setHidden(String postId, {required bool hidden});

  /// Deletes the post for good, with its photos, likes and comments.
  Future<void> delete(String postId);
}

class SupabasePostManagementService implements PostManagementService {
  const SupabasePostManagementService(this._client);
  final SupabaseClient _client;

  static const _bucket = 'report-images';

  @override
  Future<void> setHidden(String postId, {required bool hidden}) async {
    try {
      await _client.rpc(
        'set_my_report_hidden',
        params: {'p_report_id': postId, 'p_hidden': hidden},
      );
    } catch (error) {
      throw PostActionException(_failure(error));
    }
  }

  /// Photo files go first, then the post: if the files can't be removed, the
  /// post stays whole and the user can try again. The post's rows (photos,
  /// likes, comments, notifications) are deleted with it by the database.
  @override
  Future<void> delete(String postId) async {
    try {
      final images = await _client
          .from('report_images')
          .select('storage_path')
          .eq('report_id', postId);
      // Also catches files a failed photo edit left without a row.
      final files = await _client.storage.from(_bucket).list(path: postId);
      final paths = {
        for (final image in images)
          if (image['storage_path'] is String) image['storage_path'] as String,
        for (final file in files)
          if (file.id != null) '$postId/${file.name}',
      };
      if (paths.isNotEmpty) {
        await _client.storage.from(_bucket).remove(paths.toList());
      }
      final deleted = await _client
          .from('reports')
          .delete()
          .eq('id', postId)
          .select('id');
      if (deleted.isEmpty) {
        throw const PostActionException(PostActionFailure.notFound);
      }
    } on PostActionException {
      rethrow;
    } catch (_) {
      throw const PostActionException(PostActionFailure.unknown);
    }
  }

  /// Error codes set by the database functions.
  static PostActionFailure _failure(Object error) {
    if (error is! PostgrestException) return PostActionFailure.unknown;
    return switch (error.message) {
      'report_not_found' => PostActionFailure.notFound,
      'report_not_public' => PostActionFailure.notPublic,
      _ => PostActionFailure.unknown,
    };
  }
}

final postManagementServiceProvider = Provider<PostManagementService>(
  (ref) => SupabasePostManagementService(ref.watch(supabaseClientProvider)),
);
