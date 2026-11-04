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
    final PreparedPostPhoto? photo;
    try {
      photo = draft.photoPath == null
          ? null
          : await _photos.prepare(draft.photoPath!);
      if (photo != null &&
          photo.bytes.length > DevicePostPhotoService.maxBytes) {
        throw const FormatException(
          'The processed photo exceeds 5 MB. Choose a smaller photo.',
        );
      }
    } on FormatException catch (error) {
      throw PostSubmissionException(error.message);
    } catch (_) {
      throw const PostSubmissionException(
        'Could not read this photo. Choose another photo.',
      );
    }
    // Each lookup is billed, so it waits until the post has passed every check.
    final placeName = await _placeNames.lookup(draft.latitude, draft.longitude);
    String? reportId;
    String? storagePath;
    try {
      final report = await _client
          .from('reports')
          .insert({...row, 'place_name': placeName})
          .select('id')
          .single();
      reportId = report['id'] as String;
      if (photo != null) {
        // {report_id}/{filename}: no user id, so shared photos stay anonymous.
        // Storage only accepts uploads while the report is still pending.
        storagePath = '$reportId/photo.webp';
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
      return reportId;
    } catch (_) {
      // Storage and Postgres do not share a transaction. Remove partial writes.
      var cleanupFailed = false;
      if (storagePath != null) {
        try {
          await _client.storage.from('report-images').remove([storagePath]);
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
