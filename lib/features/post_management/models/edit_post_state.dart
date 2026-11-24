import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';

/// One photo on the Edit post screen: one the post already has, or one
/// picked on this screen.
sealed class EditablePhoto {
  const EditablePhoto();

  /// Tells photos apart, also to know which photo an AI analysis is about.
  String get key;

  @override
  bool operator ==(Object other) =>
      other is EditablePhoto &&
      other.runtimeType == runtimeType &&
      other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// A photo the post already has.
class ExistingPhoto extends EditablePhoto {
  const ExistingPhoto({
    required this.imageId,
    required this.storagePath,
    this.url,
  });

  /// The `report_images` row.
  final String imageId;
  final String storagePath;

  /// Signed link to show it; null when it could not be signed.
  final String? url;

  @override
  String get key => 'image:$imageId';
}

/// A photo picked on this screen, still only on the phone.
class NewPhoto extends EditablePhoto {
  const NewPhoto(this.path);
  final String path;

  @override
  String get key => 'file:$path';
}

/// The post as it was when the Edit post screen opened.
class EditablePost {
  const EditablePost({
    required this.id,
    required this.status,
    required this.category,
    this.description = '',
    this.photos = const [],
  });

  final String id;
  final ReportStatus status;
  final ReportCategory category;
  final String description;

  /// In order; the first is the cover.
  final List<ExistingPhoto> photos;
}

/// How a save ended, for the message shown afterwards.
enum EditPostOutcome {
  /// Only the caption changed; the post kept its status.
  saved,

  /// The photos changed, so the post is waiting for an admin again.
  sentForReview,
}

/// Presentation state of the Edit post screen.
class EditPostState {
  const EditPostState({
    this.original,
    this.isLoading = false,
    this.hasError = false,
    this.description = '',
    this.photos = const [],
    this.analysis,
    this.analysisFor,
    this.isBusy = false,
    this.isSaving = false,
    this.error,
    this.photoNotice,
    this.outcome,
  });

  /// The post as loaded; null while loading or when it could not be loaded.
  final EditablePost? original;
  final bool isLoading, hasError;

  /// The caption being typed.
  final String description;

  /// The photos in their new order; the first is the cover.
  final List<EditablePhoto> photos;

  /// The FaunaLens analysis of a new cover, and the [EditablePhoto.key] of
  /// the photo it is about. It only counts while that photo is the cover.
  final AiIdentification? analysis;
  final String? analysisFor;

  /// Picking photos or copying one for the AI.
  final bool isBusy;
  final bool isSaving;

  /// Why saving failed.
  final String? error;

  /// Why some picked photos were left out.
  final String? photoNotice;

  /// Set once saved; the screen then closes.
  final EditPostOutcome? outcome;

  static const maxPhotos = PostDraft.maxPhotos;

  EditablePhoto? get cover => photos.isEmpty ? null : photos.first;

  /// The cover is not the one the post had.
  bool get coverChanged {
    final first = original?.photos.firstOrNull;
    final cover = this.cover;
    return cover == null || first == null || cover.key != first.key;
  }

  /// The photos (or their order) differ from the post's.
  bool get photosChanged {
    final before = original?.photos ?? const [];
    if (before.length != photos.length) return true;
    for (var i = 0; i < photos.length; i++) {
      if (photos[i].key != before[i].key) return true;
    }
    return false;
  }

  bool get captionChanged =>
      description.trim() != (original?.description ?? '').trim();

  bool get hasChanges => photosChanged || captionChanged;

  /// The analysis of the current cover, when there is one.
  AiIdentification? get coverAnalysis =>
      analysisFor != null && analysisFor == cover?.key ? analysis : null;

  /// A new cover must be analysed before saving.
  bool get needsAnalysis =>
      photosChanged && coverChanged && cover != null && coverAnalysis == null;

  /// The category the post will have: the new analysis's, else its own.
  ReportCategory? get category =>
      (photosChanged ? coverAnalysis?.category : null) ?? original?.category;

  int get freePhotoSlots => maxPhotos - photos.length;

  /// A photo change sends an approved post back for review.
  bool get sendsForReview => photosChanged;

  bool get canSave =>
      original != null &&
      !isLoading &&
      !isBusy &&
      !isSaving &&
      outcome == null &&
      hasChanges &&
      photos.isNotEmpty &&
      !needsAnalysis;

  EditPostState copyWith({
    EditablePost? original,
    bool? isLoading,
    bool? hasError,
    String? description,
    List<EditablePhoto>? photos,
    AiIdentification? analysis,
    String? analysisFor,
    bool clearAnalysis = false,
    bool? isBusy,
    bool? isSaving,
    String? error,
    bool clearError = false,
    String? photoNotice,
    bool clearPhotoNotice = false,
    EditPostOutcome? outcome,
  }) => EditPostState(
    original: original ?? this.original,
    isLoading: isLoading ?? this.isLoading,
    hasError: hasError ?? this.hasError,
    description: description ?? this.description,
    photos: photos ?? this.photos,
    analysis: clearAnalysis ? null : analysis ?? this.analysis,
    analysisFor: clearAnalysis ? null : analysisFor ?? this.analysisFor,
    isBusy: isBusy ?? this.isBusy,
    isSaving: isSaving ?? this.isSaving,
    error: clearError ? null : error ?? this.error,
    photoNotice: clearPhotoNotice ? null : photoNotice ?? this.photoNotice,
    outcome: outcome ?? this.outcome,
  );
}
