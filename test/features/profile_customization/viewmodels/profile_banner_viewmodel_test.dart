import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/profile_customization/services/profile_service.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_banner_viewmodel.dart';

class _MockProfileService implements ProfileService {
  String? savedBanner;
  int? savedColor;
  bool shouldSucceed = true;

  @override
  Future<bool> saveProfile({
    required String username,
    required String bio,
  }) async => true;

  @override
  Future<bool> saveProfilePicture({
    String? presetAvatar,
    String? customImagePath,
  }) async => true;

  @override
  Future<bool> saveProfileBanner({String? bannerAsset, int? colorValue}) async {
    savedBanner = bannerAsset;
    savedColor = colorValue;
    return shouldSucceed;
  }
}

void main() {
  group('ProfileBannerViewModel', () {
    late _MockProfileService mockProfileService;
    late ProfileBannerViewModel viewModel;

    setUp(() {
      mockProfileService = _MockProfileService();
      viewModel = ProfileBannerViewModel(mockProfileService);
    });

    test('initial state has no banner and no color selected', () {
      expect(viewModel.state.selectedBanner, isNull);
      expect(viewModel.state.selectedColor, isNull);
      expect(viewModel.state.isContinueEnabled, isFalse);
      expect(viewModel.state.isSubmitting, isFalse);
    });

    test(
      'selectBanner selects banner, clears any color, and enables continue',
      () {
        viewModel.selectColor(AppColors.bannerColors.first);
        expect(viewModel.state.selectedColor, isNotNull);

        viewModel.selectBanner(AppAssets.bannerDay);
        expect(viewModel.state.selectedBanner, AppAssets.bannerDay);
        expect(viewModel.state.selectedColor, isNull);
        expect(viewModel.state.isContinueEnabled, isTrue);
      },
    );

    test(
      'selectColor selects color, clears any banner, and enables continue',
      () {
        viewModel.selectBanner(AppAssets.bannerDay);
        expect(viewModel.state.selectedBanner, isNotNull);

        viewModel.selectColor(AppColors.bannerColors[4]);
        expect(viewModel.state.selectedBanner, isNull);
        expect(viewModel.state.selectedColor, AppColors.bannerColors[4]);
        expect(viewModel.state.isContinueEnabled, isTrue);
      },
    );

    test(
      'submit calls profileService with banner when banner is selected',
      () async {
        viewModel.selectBanner(AppAssets.bannerDay);

        final success = await viewModel.submit();

        expect(success, isTrue);
        expect(mockProfileService.savedBanner, AppAssets.bannerDay);
        expect(mockProfileService.savedColor, isNull);
      },
    );

    test(
      'submit calls profileService with color when color is selected',
      () async {
        viewModel.selectColor(AppColors.bannerColors[1]);

        final success = await viewModel.submit();

        expect(success, isTrue);
        expect(mockProfileService.savedBanner, isNull);
        expect(
          mockProfileService.savedColor,
          AppColors.bannerColors[1].toARGB32(),
        );
      },
    );

    test(
      'submit does not call profileService when neither banner nor color is selected',
      () async {
        final success = await viewModel.submit();

        expect(success, isFalse);
        expect(mockProfileService.savedBanner, isNull);
        expect(mockProfileService.savedColor, isNull);
      },
    );
  });
}
