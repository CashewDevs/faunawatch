/// An optional public interest tag freely chosen by its owner.
enum ProfileTag {
  dogLover('dog_lover', 'Dog Lover'),
  catLover('cat_lover', 'Cat Lover'),
  spotter('spotter', 'Spotter');

  const ProfileTag(this.value, this.label);
  final String value;
  final String label;

  static ProfileTag? fromValue(Object? value) {
    for (final tag in values) {
      if (tag.value == value) return tag;
    }
    return null;
  }
}
