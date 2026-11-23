import 'package:faunawatch/core/constants/app_assets.dart';

/// Represents a single slide in the onboarding walkthrough flow.
class OnboardingItem {
  const OnboardingItem({
    required this.title,
    required this.description,
    required this.backgroundAsset,
  });

  final String title;
  final String description;
  final String backgroundAsset;

  /// Default welcoming slides shown to new users.
  static const List<OnboardingItem> defaultItems = [
    OnboardingItem(
      title: 'Spot & Identify',
      description:
          'Scan encounters through your camera to\nidentify species and risk levels.',
      backgroundAsset: AppAssets.onboardingBg1,
    ),
    OnboardingItem(
      title: 'Real-Time Alerts',
      description:
          'Track live encounters and stay\nupdated on sightings near you.',
      backgroundAsset: AppAssets.onboardingBg2,
    ),
    OnboardingItem(
      title: 'Protect & Report',
      description: 'Report animals in need and keep\nyour neighborhood safe.',
      backgroundAsset: AppAssets.onboardingBg3,
    ),
  ];
}
