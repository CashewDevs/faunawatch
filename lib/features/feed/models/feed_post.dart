import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';

/// An approved report as shown in the For You feed, built from one row of the
/// `community_feed()` RPC.
///
/// The row never has exact coordinates, `user_notes` or admin fields, so none
/// exist here. Photos and the author's picture live in private Storage buckets;
/// the service fills in their signed URLs.
class FeedPost {
  const FeedPost({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.feedAt,
    required this.authorId,
    required this.authorName,
    this.category,
    this.categoryLabel = fallbackTitle,
    this.description = '',
    this.severity,
    this.aiSpeciesGuess,
    this.possibleInvasive = false,
    this.placeName,
    this.authorAvatarPath,
    this.authorAvatarAsset,
    this.authorAvatarUrl,
    this.photoPaths = const [],
    this.photoUrls = const [],
    this.likeCount = 0,
    this.likedByMe = false,
    this.commentCount = 0,
  });

  static const fallbackTitle = 'Wildlife report';
  static const fallbackAuthorName = 'FaunaWatch user';

  /// Shown when a report has no place name.
  static const approximateLocation = 'Approximate location';

  /// Shown whenever the AI's severity, species guess or invasive flag is.
  static const aiNote = 'Preliminary AI-assisted suggestions. AI can be wrong.';

  final String id;

  /// The user's species, else the AI's top guess, else the category label.
  final String title;

  /// When the report was submitted.
  final DateTime createdAt;

  /// The sort time: when the report was approved (falls back to [createdAt]).
  /// Together with [id] it is the paging cursor.
  final DateTime feedAt;
  final String authorId, authorName;
  final ReportCategory? category;
  final String categoryLabel;
  final String description;
  final SeverityLevel? severity;

  /// The AI's most likely species, from the completed analysis.
  final String? aiSpeciesGuess;
  final bool possibleInvasive;

  /// `reports.place_name` exactly as stored, e.g. "Lusod, Kabayan, Benguet".
  final String? placeName;

  /// `profiles.avatar_path`: `preset:<name>` or a path in the avatars bucket.
  final String? authorAvatarPath;
  final String? authorAvatarAsset, authorAvatarUrl;

  /// Storage paths in `report-images`, in display order.
  final List<String> photoPaths;

  /// Signed URLs for the photos that could be signed, in display order.
  final List<String> photoUrls;
  final int likeCount, commentCount;
  final bool likedByMe;

  /// The place name, or "Approximate location" when there is none.
  String get location {
    final name = placeName?.trim();
    return name == null || name.isEmpty ? approximateLocation : name;
  }

  /// Whether any AI result is shown, so the preliminary note must be too.
  bool get hasAiContent =>
      severity != null || aiSpeciesGuess != null || possibleInvasive;

  factory FeedPost.fromJson(Map<String, dynamic> row) {
    final category = _category(row['category']);
    final aiGuess = _topSpecies(row['possible_species']);
    final userSpecies = _clean(row['user_species']);
    final categoryLabel = category?.label ?? fallbackTitle;
    final severityText = _clean(row['severity']);
    final createdAt = DateTime.parse(row['created_at'] as String);
    return FeedPost(
      id: row['id'] as String,
      title: userSpecies ?? aiGuess ?? categoryLabel,
      createdAt: createdAt,
      feedAt: DateTime.parse(
        _clean(row['feed_at']) ?? row['created_at'] as String,
      ),
      authorId: row['author_id'] as String,
      authorName: _clean(row['author_name']) ?? fallbackAuthorName,
      category: category,
      categoryLabel: categoryLabel,
      description: _clean(row['description']) ?? '',
      severity: severityText == null ? null : SeverityLevel.parse(severityText),
      aiSpeciesGuess: aiGuess,
      possibleInvasive: row['possible_invasive'] == true,
      placeName: _clean(row['place_name']),
      authorAvatarPath: _clean(row['author_avatar_path']),
      photoPaths: [
        for (final path in (row['photo_paths'] as List?) ?? const [])
          if (path is String && path.isNotEmpty) path,
      ],
      likeCount: (row['like_count'] as num?)?.toInt() ?? 0,
      likedByMe: row['liked_by_me'] == true,
      commentCount: (row['comment_count'] as num?)?.toInt() ?? 0,
    );
  }

  FeedPost copyWith({
    int? likeCount,
    bool? likedByMe,
    int? commentCount,
    List<String>? photoUrls,
    String? authorAvatarAsset,
    String? authorAvatarUrl,
  }) {
    return FeedPost(
      id: id,
      title: title,
      createdAt: createdAt,
      feedAt: feedAt,
      authorId: authorId,
      authorName: authorName,
      category: category,
      categoryLabel: categoryLabel,
      description: description,
      severity: severity,
      aiSpeciesGuess: aiSpeciesGuess,
      possibleInvasive: possibleInvasive,
      placeName: placeName,
      authorAvatarPath: authorAvatarPath,
      authorAvatarAsset: authorAvatarAsset ?? this.authorAvatarAsset,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      photoPaths: photoPaths,
      photoUrls: photoUrls ?? this.photoUrls,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      commentCount: commentCount ?? this.commentCount,
    );
  }

  static String? _clean(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static ReportCategory? _category(Object? value) {
    for (final category in ReportCategory.values) {
      if (category.value == value) return category;
    }
    return null;
  }

  /// The first guess's name. Rows are written with `common_name`; the older
  /// documented shape used `name`.
  static String? _topSpecies(Object? value) {
    if (value is! List || value.isEmpty) return null;
    final first = value.first;
    if (first is! Map) return null;
    return _clean(first['common_name']) ?? _clean(first['name']);
  }
}

/// Shortens large counts for tight layouts, e.g. 1406 becomes 1.4K.
String formatCompactCount(int count) {
  if (count < 1000) return '$count';
  final thousands = (count / 100).floor() / 10;
  final label = thousands == thousands.truncateToDouble()
      ? thousands.toStringAsFixed(0)
      : thousands.toStringAsFixed(1);
  return '${label}K';
}

/// Short age label, e.g. `37m` or `22h`.
String formatPostAge(DateTime time, DateTime now) {
  final age = now.difference(time);
  if (age.inMinutes < 1) return 'now';
  if (age.inHours < 1) return '${age.inMinutes}m';
  if (age.inDays < 1) return '${age.inHours}h';
  if (age.inDays < 7) return '${age.inDays}d';
  return '${age.inDays ~/ 7}w';
}
