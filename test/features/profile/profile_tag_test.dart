import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/profile/models/profile_tag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all supported tags preserve their stored values and public labels', () {
    expect(ProfileTag.values.map((tag) => tag.label), [
      'Dog Lover',
      'Cat Lover',
      'Spotter',
    ]);
    for (final tag in ProfileTag.values) {
      expect(ProfileTag.fromValue(tag.value), tag);
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
