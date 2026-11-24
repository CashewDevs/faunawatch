import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/create_post/services/post_photo_picker_service.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/post_management/models/edit_post_state.dart';
import 'package:faunawatch/features/post_management/services/edit_post_service.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';

const coverPhoto = ExistingPhoto(
  imageId: 'img-1',
  storagePath: 'post-1/photo-1.webp',
  url: 'https://photos.invalid/1.webp',
);
const secondPhoto = ExistingPhoto(
  imageId: 'img-2',
  storagePath: 'post-1/photo-2.webp',
  url: 'https://photos.invalid/2.webp',
);

/// An approved post with a caption and two photos.
EditablePost samplePost({
  ReportStatus status = ReportStatus.approved,
  List<ExistingPhoto> photos = const [coverPhoto, secondPhoto],
}) => EditablePost(
  id: 'post-1',
  status: status,
  category: ReportCategory.animalInNeed,
  description: 'Old caption',
  photos: photos,
);

/// Records what the Edit post screen saved; [error] makes saving fail.
class FakeEditPostService implements EditPostService {
  FakeEditPostService({this.post});

  EditablePost? post;
  Object? loadError, error;
  final captions = <String>[];
  final replaced = <(List<EditablePhoto>, AiIdentification?)>[];
  final copies = <String>[];

  @override
  Future<EditablePost?> load(String postId) async {
    if (loadError != null) throw loadError!;
    return post;
  }

  @override
  Future<String> localCopy(ExistingPhoto photo) async {
    copies.add(photo.imageId);
    return '/tmp/${photo.imageId}.webp';
  }

  @override
  Future<void> updateCaption(String postId, String description) async {
    if (error != null) throw error!;
    captions.add(description);
  }

  @override
  Future<void> replacePhotos(
    String postId,
    List<EditablePhoto> photos, {
    AiIdentification? analysis,
  }) async {
    if (error != null) throw error!;
    replaced.add((photos, analysis));
  }
}

class FakePhotoPicker implements PostPhotoPickerService {
  String? taken;
  List<String> picked = [];
  final tooLarge = <String>{};
  final limits = <int>[];

  @override
  Future<String?> takePhoto() async => taken;

  @override
  Future<List<String>> pickPhotos({required int limit}) async {
    limits.add(limit);
    return picked;
  }

  @override
  Future<bool> isTooLarge(String path) async => tooLarge.contains(path);
}
