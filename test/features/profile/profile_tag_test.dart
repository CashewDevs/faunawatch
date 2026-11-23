import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/profile/models/profile_tag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProfileTagActivity activity(int total, int dogs, int cats) =>
      ProfileTagActivity(
        approvedReports: total,
        dogReports: dogs,
        catReports: cats,
      );

  test('suggestions start at three approved reports', () {
    expect(activity(0, 0, 0).suggestions, isEmpty);
    expect(activity(2, 2, 0).suggestions, isEmpty);
    expect(activity(2, 0, 2).suggestions, isEmpty);
    expect(activity(3, 3, 0).suggestions, [ProfileTag.dogLover]);
    expect(activity(3, 0, 3).suggestions, [ProfileTag.catLover]);
    expect(activity(3, 2, 0).suggestions, [ProfileTag.dogLover]);
    expect(activity(3, 0, 2).suggestions, [ProfileTag.catLover]);
    expect(activity(3, 1, 1).suggestions, [ProfileTag.spotter]);
  });

  test(
    'the 60 percent boundary is inclusive and mixed activity is Spotter',
    () {
      expect(activity(10, 6, 0).suggestions, [ProfileTag.dogLover]);
      expect(activity(10, 5, 5).suggestions, [ProfileTag.spotter]);
      expect(activity(3, 0, 0).suggestions, [ProfileTag.spotter]);
    },
  );

  test('mixed-animal reports can offer both tags for the owner to choose', () {
    expect(activity(3, 2, 2).suggestions, [
      ProfileTag.dogLover,
      ProfileTag.catLover,
    ]);
  });

  test('activity parsing rejects invalid counts', () {
    expect(
      ProfileTagActivity.fromJson({
        'approved_reports': 5,
        'dog_reports': 3,
        'cat_reports': 1,
      }).suggestions,
      [ProfileTag.dogLover],
    );
    for (final row in [
      {'approved_reports': -1, 'dog_reports': 0, 'cat_reports': 0},
      {'approved_reports': 5, 'dog_reports': 6, 'cat_reports': 0},
      {'approved_reports': 5, 'dog_reports': 0.5, 'cat_reports': 0},
      {'approved_reports': 5, 'dog_reports': 0},
    ]) {
      expect(() => ProfileTagActivity.fromJson(row), throwsFormatException);
    }
  });

  test(
    'unknown tags stay hidden and ordinary profile changes preserve a tag',
    () {
      expect(ProfileTag.fromValue('dog_lover'), ProfileTag.dogLover);
      expect(ProfileTag.fromValue(null), isNull);
      expect(ProfileTag.fromValue('unknown'), isNull);
      const profile = ProfileData(profileTag: ProfileTag.dogLover);
      expect(profile.copyWith(bio: 'New bio').profileTag, ProfileTag.dogLover);
      expect(profile.copyWith(clearProfileTag: true).profileTag, isNull);
    },
  );
}
