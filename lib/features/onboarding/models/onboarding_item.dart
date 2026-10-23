/// Represents a single slide in the onboarding walkthrough flow.
class OnboardingItem {
  const OnboardingItem({required this.title, required this.description});

  final String title;
  final String description;

  /// Default welcoming slides shown to new users.
  static const List<OnboardingItem> defaultItems = [
    OnboardingItem(
      title: 'Spot & Identify',
      description:
          'Scan encounters through your camera to\nidentify species and risk levels.',
    ),
    OnboardingItem(
      title: 'Real-Time Alerts',
      description:
          'Track live encounters and stay\nupdated on sightings near you.',
    ),
    OnboardingItem(
      title: 'Protect & Report',
      description: 'Report animals in need and keep\nyour neighborhood safe.',
    ),
  ];
}
