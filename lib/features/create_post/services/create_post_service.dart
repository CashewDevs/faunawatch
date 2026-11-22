import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import '../models/post_draft.dart';
import 'place_name_service.dart';
import 'post_photo_service.dart';

abstract interface class CreatePostService {
  Future<String> submit(PostDraft draft);
}

class PostSubmissionException implements Exception {
  const PostSubmissionException(this.message);
  final String message;
}

class SupabaseCreatePostService implements CreatePostService {
  const SupabaseCreatePostService(this._client, this._photos, this._placeNames);
  final SupabaseClient _client;
  final PostPhotoService _photos;
  final PlaceNameService _placeNames;

  @override
  Future<String> submit(PostDraft draft) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const PostSubmissionException('Sign in to create a post.');
    }
    final row = draft.toRow(user.id);
    final paths = draft.photoPaths;
    // Every photo is prepared before anything is saved, so a bad photo stops
    // the post early.
    final photos = <PreparedPostPhoto>[];
    for (var i = 0; i < paths.length; i++) {
      // With several photos, say which one is the problem.
      final which = paths.length == 1 ? '' : 'Photo ${i + 1}: ';
      try {
        final photo = await _photos.prepare(paths[i]);
        if (photo.bytes.length > DevicePostPhotoService.maxBytes) {
          throw const FormatException(
            'The processed photo exceeds 5 MB. Choose a smaller photo.',
          );
        }
        photos.add(photo);
      } on FormatException catch (error) {
        throw PostSubmissionException('$which${error.message}');
      } catch (_) {
        throw PostSubmissionException(
          '${which}Could not read this photo. Choose another photo.',
        );
      }
    }
    // Each lookup is billed, so it waits until the post has passed every check.
    final placeName = await _placeNames.lookup(draft.latitude, draft.longitude);
    String? reportId;
    final storagePaths = <String>[];
    try {
      final report = await _client
          .from('reports')
          .insert({...row, 'place_name': placeName})
          .select('id')
          .single();
      reportId = report['id'] as String;
      // One photo at a time, cover first: the feed, the map pin and the admin
      // site order photos by when their row was saved.
      for (var i = 0; i < photos.length; i++) {
        final photo = photos[i];
        // {report_id}/{filename}: the path carries no user id.
        // Storage only accepts uploads while the report is still pending.
        final storagePath = '$reportId/photo-${i + 1}.webp';
        storagePaths.add(storagePath);
        await _client.storage
            .from('report-images')
            .uploadBinary(
              storagePath,
              photo.bytes,
              fileOptions: const FileOptions(contentType: 'image/webp'),
            );
        final image = await _client
            .from('report_images')
            .insert({
              'report_id': reportId,
              'storage_path': storagePath,
              'content_type': 'image/webp',
              'size_bytes': photo.bytes.length,
              'fingerprint': photo.fingerprint,
            })
            .select('id')
            .single();
        if (photo.exif.isNotEmpty) {
          await _client.from('report_image_exif').insert({
            'image_id': image['id'],
            ...photo.exif,
          });
        }
      }
      // Must happen while the report is still pending: only its owner may
      // insert, and only then (ai_analyses_insert_own_pending). Rows are
      // write-once, so the whole result goes in one insert. A failure falls
      // through to the cleanup below, which also keeps ai_status honest.
      final analysis = draft.analysis;
      if (analysis != null) {
        await _client
            .from('ai_analyses')
            .insert(analysis.toAnalysisRow(reportId));
      }
      return reportId;
    } catch (_) {
      // Storage and Postgres do not share a transaction. Remove partial writes.
      var cleanupFailed = false;
      if (storagePaths.isNotEmpty) {
        try {
          await _client.storage.from('report-images').remove(storagePaths);
        } catch (_) {
          cleanupFailed = true;
        }
      }
      if (reportId != null) {
        try {
          await _client.from('reports').delete().eq('id', reportId);
        } catch (_) {
          cleanupFailed = true;
        }
      }
      throw PostSubmissionException(
        cleanupFailed
            ? 'Submission was interrupted and may have been saved. Please check before posting again.'
            : 'Could not submit your post. Please try again.',
      );
    }
  }
}

final createPostServiceProvider = Provider<CreatePostService>(
  (ref) => SupabaseCreatePostService(
    ref.read(supabaseClientProvider),
    ref.read(postPhotoServiceProvider),
    ref.read(placeNameServiceProvider),
  ),
);
