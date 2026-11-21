import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/models/post_comment.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({Map<String, dynamic>? overrides}) => {
  'id': 'report-1',
  'category': 'animal_in_need',
  'description': 'Injured near the road.',
  'user_species': null,
  'severity': null,
  'possible_species': null,
  'possible_invasive': null,
  'place_name': 'Lusod, Kabayan, Benguet',
  'author_id': 'author-1',
  'author_name': 'spotter_one',
  'author_avatar_path': 'preset:bunny',
  'photo_paths': ['report-1/photo.webp'],
  'like_count': 3,
  'liked_by_me': true,
  'comment_count': 2,
  'created_at': '2026-11-12T08:00:00+00:00',
  'feed_at': '2026-11-12T09:30:00+00:00',
  ...?overrides,
};

void main() {
  group('FeedPost.fromJson', () {
    test('maps a community_feed row', () {
      final post = FeedPost.fromJson(_row());
      expect(post.id, 'report-1');
      expect(post.category, ReportCategory.animalInNeed);
      expect(post.categoryLabel, 'Animal in need');
      expect(post.description, 'Injured near the road.');
      expect(post.placeName, 'Lusod, Kabayan, Benguet');
      expect(post.location, 'Lusod, Kabayan, Benguet');
      expect(post.authorId, 'author-1');
      expect(post.authorName, 'spotter_one');
      expect(post.authorAvatarPath, 'preset:bunny');
      expect(post.photoPaths, ['report-1/photo.webp']);
      expect(post.photoUrls, isEmpty);
      expect(post.likeCount, 3);
      expect(post.likedByMe, isTrue);
      expect(post.commentCount, 2);
      expect(post.createdAt, DateTime.utc(2026, 11, 12, 8));
      expect(post.feedAt, DateTime.utc(2026, 11, 12, 9, 30));
    });

    test('titles a post with the user species first', () {
      final post = FeedPost.fromJson(
        _row(
          overrides: {
            'user_species': '  Philippine Eagle ',
            'possible_species': [
              {'common_name': 'Hawk'},
            ],
          },
        ),
      );
      expect(post.title, 'Philippine Eagle');
    });

    test('falls back to the AI top guess, then the category label', () {
      final guess = FeedPost.fromJson(
        _row(
          overrides: {
            'user_species': '  ',
            'possible_species': [
              {'common_name': 'Tarsier', 'confidence': 'high'},
              {'common_name': 'Loris'},
            ],
          },
        ),
      );
      expect(guess.title, 'Tarsier');
      expect(guess.aiSpeciesGuess, 'Tarsier');
      expect(guess.hasAiContent, isTrue);

      final legacyShape = FeedPost.fromJson(
        _row(
          overrides: {
            'possible_species': [
              {'name': 'Heron'},
            ],
          },
        ),
      );
      expect(legacyShape.title, 'Heron');

      for (final species in [null, <Object>[]]) {
        final post = FeedPost.fromJson(
          _row(overrides: {'possible_species': species}),
        );
        expect(post.title, 'Animal in need');
        expect(post.aiSpeciesGuess, isNull);
        expect(post.hasAiContent, isFalse);
      }
    });

    test('an unknown category still has a title', () {
      final post = FeedPost.fromJson(_row(overrides: {'category': 'new_one'}));
      expect(post.category, isNull);
      expect(post.title, 'Wildlife report');
    });

    test('a missing or blank place name shows Approximate location', () {
      for (final name in [null, '', '   ']) {
        final post = FeedPost.fromJson(_row(overrides: {'place_name': name}));
        expect(post.placeName, isNull);
        expect(post.location, 'Approximate location');
      }
    });

    test('reads the AI severity and invasive flag', () {
      final post = FeedPost.fromJson(
        _row(overrides: {'severity': 'high', 'possible_invasive': true}),
      );
      expect(post.severity, SeverityLevel.high);
      expect(post.possibleInvasive, isTrue);
      expect(post.hasAiContent, isTrue);
      expect(FeedPost.aiNote, contains('Preliminary AI-assisted'));
    });

    test('tolerates sparse rows', () {
      final post = FeedPost.fromJson({
        'id': 'r',
        'category': 'other_wildlife_incident',
        'author_id': 'a',
        'created_at': '2026-11-12T08:00:00Z',
      });
      expect(post.authorName, 'FaunaWatch user');
      expect(post.description, '');
      expect(post.photoPaths, isEmpty);
      expect(post.likeCount, 0);
      expect(post.likedByMe, isFalse);
      expect(post.commentCount, 0);
      expect(post.feedAt, post.createdAt);
      expect(post.hasAiContent, isFalse);
    });

    test('copyWith keeps the rest of the post', () {
      final post = FeedPost.fromJson(_row());
      final liked = post.copyWith(likedByMe: false, likeCount: 2);
      expect(liked.likedByMe, isFalse);
      expect(liked.likeCount, 2);
      expect(liked.title, post.title);
      expect(liked.feedAt, post.feedAt);
      expect(liked.commentCount, post.commentCount);
    });
  });

  group('AI analysis and map point', () {
    test('reads every public AI field and ignores the responder briefing', () {
      final post = FeedPost.fromJson(
        _row(
          overrides: {
            'severity': 'high',
            'possible_species': [
              {
                'common_name': 'Cane toad',
                'scientific_name': 'Rhinella marina',
                'confidence': 'medium',
              },
              {'name': 'Common toad'},
              {'common_name': ' '},
            ],
            'possible_invasive': true,
            'invasive_match_name': 'Cane toad',
            'visual_condition_assessment': 'Alert, no visible injury.',
            'incident_summary': 'A toad on a garden path.',
            'safety_recommendations': 'Do not touch it.',
            'community_warning': 'Keep pets away.',
            'responder_briefing': 'Admin-only text.',
          },
        ),
      );
      final ai = post.aiAnalysis!;
      expect(ai.species.map((s) => s.commonName), ['Cane toad', 'Common toad']);
      expect(ai.species.first.scientificName, 'Rhinella marina');
      expect(ai.species.first.confidence, SpeciesConfidence.medium);
      expect(ai.species.last.confidence, SpeciesConfidence.uncertain);
      expect(ai.severity, SeverityLevel.high);
      expect(ai.possibleInvasive, isTrue);
      expect(ai.invasiveMatchName, 'Cane toad');
      expect(ai.visualCondition, 'Alert, no visible injury.');
      expect(ai.incidentSummary, 'A toad on a garden path.');
      expect(ai.safetyRecommendations, 'Do not touch it.');
      expect(ai.communityWarning, 'Keep pets away.');
      expect(post.hasAiContent, isTrue);
    });

    test('a row without any AI result has no analysis', () {
      final post = FeedPost.fromJson(
        _row(overrides: {'safety_recommendations': '  '}),
      );
      expect(post.aiAnalysis, isNull);
      expect(post.hasAiContent, isFalse);
    });

    test('an AI text alone still counts as AI content', () {
      final post = FeedPost.fromJson(
        _row(overrides: {'visual_condition_assessment': 'Limping.'}),
      );
      expect(post.aiAnalysis!.visualCondition, 'Limping.');
      expect(post.hasAiContent, isTrue);
    });

    test('coordinates are always rounded to about 1 km', () {
      final post = FeedPost.fromJson(
        _row(overrides: {'latitude': 16.456789, 'longitude': 120.987654}),
      );
      expect(post.approxLatitude, 16.46);
      expect(post.approxLongitude, 120.99);
      expect(post.hasMapLocation, isTrue);
      final copy = post.copyWith(likeCount: 9);
      expect(copy.approxLatitude, 16.46);
      expect(copy.aiAnalysis, same(post.aiAnalysis));
    });

    test('a row without coordinates has no map point', () {
      final post = FeedPost.fromJson(_row(overrides: {'latitude': 16.4}));
      expect(post.approxLatitude, 16.4);
      expect(post.approxLongitude, isNull);
      expect(post.hasMapLocation, isFalse);
    });
  });

  group('PostComment.fromJson', () {
    Map<String, dynamic> comment(Map<String, dynamic>? profile) => {
      'id': 'c1',
      'user_id': 'u1',
      'body': '  Nice find  ',
      'created_at': '2026-11-12T09:00:00Z',
      'profiles': profile,
    };

    test('uses the same name fallbacks as the chat list', () {
      expect(
        PostComment.fromJson(
          comment({'username': 'bird_notes', 'full_name': 'Bird Notes'}),
        ).authorName,
        'bird_notes',
      );
      expect(
        PostComment.fromJson(
          comment({'username': '', 'full_name': 'Bird Notes'}),
        ).authorName,
        'Bird Notes',
      );
      expect(
        PostComment.fromJson(
          comment({'username': null, 'display_name': 'Old Name'}),
        ).authorName,
        'Old Name',
      );
      expect(PostComment.fromJson(comment(null)).authorName, 'FaunaWatch user');
    });

    test('trims the text and keeps the avatar path', () {
      final result = PostComment.fromJson(
        comment({'username': 'a_b', 'avatar_path': 'u1/me.webp'}),
      );
      expect(result.text, 'Nice find');
      expect(result.authorAvatarPath, 'u1/me.webp');
      expect(result.createdAt, DateTime.utc(2026, 11, 12, 9));
    });
  });

  test('formatCompactCount and formatPostAge', () {
    expect(formatCompactCount(999), '999');
    expect(formatCompactCount(1000), '1K');
    expect(formatCompactCount(1406), '1.4K');
    expect(formatCompactCount(14500), '14.5K');
    final now = DateTime.utc(2026, 11, 12, 12);
    expect(formatPostAge(now, now), 'now');
    expect(
      formatPostAge(now.subtract(const Duration(minutes: 37)), now),
      '37m',
    );
    expect(formatPostAge(now.subtract(const Duration(hours: 22)), now), '22h');
    expect(formatPostAge(now.subtract(const Duration(days: 3)), now), '3d');
    expect(formatPostAge(now.subtract(const Duration(days: 15)), now), '2w');
  });
}
