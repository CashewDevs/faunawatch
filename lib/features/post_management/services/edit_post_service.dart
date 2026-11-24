import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/create_post/services/post_photo_service.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/post_management/models/edit_post_state.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';

/// Why an edit could not be saved, with the text shown to the user.
class EditPostException implements Exception {
  const EditPostException(this.message);
  final String message;

  static const notFound = EditPostException(
    'This post is no longer available.',
  );
  static const suspended = EditPostException(
    "You can't edit posts while your account is suspended.",
  );
  static const notEditable = EditPostException(
    "This post can't be edited any more.",
  );
  static const failed = EditPostException(
    'Could not save your changes. Check your connection and try again.',
  );

  @override
  String toString() => 'EditPostException($message)';
}

/// Loads and saves the signed-in user's own post for the Edit post screen.
/// The database checks that the post is theirs and may still be edited (see
/// `20261124170000_add_edit_hide_delete_posts.sql`).
abstract interface class EditPostService {
  /// The post with its photos in order, or null when it is not the user's
  /// (any more).
  Future<EditablePost?> load(String postId);

  /// A file on the phone with [photo]'s picture, for the AI to read.
  Future<String> localCopy(ExistingPhoto photo);

  /// Saves a new caption; the post keeps its status.
  Future<void> updateCaption(String postId, String description);

  /// Replaces the photos with [photos] (in order, the first is the cover)
  /// and sends the post back for review. [analysis] is required when the
  /// cover is new; it also sets the category. Throws [EditPostException].
  Future<void> replacePhotos(
    String postId,
    List<EditablePhoto> photos, {
    AiIdentification? analysis,
  });
}

class SupabaseEditPostService implements EditPostService {
  const SupabaseEditPostService(this._client, this._photos);
  final SupabaseClient _client;
  final PostPhotoService _photos;

  static const _bucket = 'report-images';
  static const _urlLifetimeSeconds = 3600;

  @override
  Future<EditablePost?> load(String postId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('reports')
        .select(
          'id, status, category, description, '
          'report_images(id, storage_path, created_at)',
        )
        .eq('id', postId)
        .eq('user_id', userId)
        .order('created_at', ascending: true, referencedTable: 'report_images')
        .order('id', ascending: true, referencedTable: 'report_images')
        .maybeSingle();
    if (row == null) return null;
    final category = ReportCategory.values
        .where((category) => category.value == row['category'])
        .firstOrNull;
    if (category == null) return null;
    final photos = await Future.wait([
      for (final image in (row['report_images'] as List?) ?? const [])
        if (image is Map && image['storage_path'] is String)
          _existing(image['id'] as String, image['storage_path'] as String),
    ]);
    return EditablePost(
      id: postId,
      status: ReportStatus.fromDb(row['status'] as String?),
      category: category,
      description: (row['description'] as String?)?.trim() ?? '',
      photos: photos,
    );
  }

  Future<ExistingPhoto> _existing(String imageId, String path) async {
    String? url;
    try {
      url = await _client.storage
          .from(_bucket)
          .createSignedUrl(path, _urlLifetimeSeconds);
    } catch (_) {
      // Shown as a placeholder; the photo can still be kept or removed.
    }
    return ExistingPhoto(imageId: imageId, storagePath: path, url: url);
  }

  @override
  Future<String> localCopy(ExistingPhoto photo) async {
    // On the web the AI reads a link as easily as a file.
    if (kIsWeb) {
      return photo.url ??
          await _client.storage
              .from(_bucket)
              .createSignedUrl(photo.storagePath, _urlLifetimeSeconds);
    }
    final bytes = await _client.storage
        .from(_bucket)
        .download(photo.storagePath);
    final folder = await Directory.systemTemp.createTemp('faunawatch_edit');
    final file = File('${folder.path}/${photo.imageId}.webp');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<void> updateCaption(String postId, String description) async {
    try {
      await _client.rpc(
        'update_my_report_caption',
        params: {'p_report_id': postId, 'p_description': description},
      );
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<void> replacePhotos(
    String postId,
    List<EditablePhoto> photos, {
    AiIdentification? analysis,
  }) async {
    if (photos.isEmpty || photos.length > PostDraft.maxPhotos) {
      throw ArgumentError.value(photos.length, 'photos', 'must be 1 to 3');
    }
    // Every new photo is prepared (resized, location data removed) before
    // anything is uploaded, so a bad photo stops the edit early.
    final prepared = <String, PreparedPostPhoto>{};
    final newPhotos = photos.whereType<NewPhoto>().toList();
    for (var i = 0; i < newPhotos.length; i++) {
      final which = newPhotos.length == 1 ? '' : 'New photo ${i + 1}: ';
      try {
        prepared[newPhotos[i].path] = await _photos.prepare(newPhotos[i].path);
      } on FormatException catch (error) {
        throw EditPostException('$which${error.message}');
      } catch (_) {
        throw EditPostException(
          '${which}Could not read this photo. Choose another photo.',
        );
      }
    }

    final uploaded = <String>[];
    try {
      // A new name each time, so an earlier failed edit never gets in the way.
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final items = <Map<String, Object?>>[];
      for (final photo in photos) {
        switch (photo) {
          case ExistingPhoto(:final imageId):
            items.add({'image_id': imageId});
          case NewPhoto(:final path):
            final ready = prepared[path]!;
            final storagePath =
                '$postId/edit-$stamp-${uploaded.length + 1}.webp';
            await _client.storage
                .from(_bucket)
                .uploadBinary(
                  storagePath,
                  ready.bytes,
                  fileOptions: const FileOptions(contentType: 'image/webp'),
                );
            uploaded.add(storagePath);
            items.add({
              'storage_path': storagePath,
              'size_bytes': ready.bytes.length,
              'fingerprint': ready.fingerprint,
              if (ready.exif.isNotEmpty) 'exif': ready.exif,
            });
        }
      }
      final removed = await _client.rpc(
        'apply_my_report_photo_edit',
        params: {
          'p_report_id': postId,
          'p_photos': items,
          'p_analysis': analysis?.toAnalysisRow(postId),
          'p_category': analysis?.category.value,
        },
      );
      uploaded.clear();
      // The photos left out are no longer part of the post. If removing the
      // files fails, deleting the post later removes them.
      final paths = [
        for (final path in (removed as List?) ?? const [])
          if (path is String) path,
      ];
      if (paths.isNotEmpty) {
        try {
          await _client.storage.from(_bucket).remove(paths);
        } catch (_) {}
      }
    } catch (error) {
      if (uploaded.isNotEmpty) {
        try {
          await _client.storage.from(_bucket).remove(uploaded);
        } catch (_) {}
      }
      throw _failure(error);
    }
  }

  /// Error codes set by the database functions.
  static EditPostException _failure(Object error) {
    if (error is EditPostException) return error;
    if (error is! PostgrestException) return EditPostException.failed;
    return switch (error.message) {
      'report_not_found' => EditPostException.notFound,
      'account_suspended' => EditPostException.suspended,
      'report_not_editable' => EditPostException.notEditable,
      _ => EditPostException.failed,
    };
  }
}

final editPostServiceProvider = Provider<EditPostService>(
  (ref) => SupabaseEditPostService(
    ref.watch(supabaseClientProvider),
    ref.read(postPhotoServiceProvider),
  ),
);
