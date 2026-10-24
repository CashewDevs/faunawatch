import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/profile_customization/views/profile_banner_view.dart';
import 'package:faunawatch/features/profile_customization/views/widgets/banner_color_item.dart';
import 'package:faunawatch/features/profile_customization/views/widgets/profile_banner_item.dart';
import 'package:faunawatch/features/profile_customization/views/widgets/profile_continue_button.dart';

void main() {
  Widget createWidgetUnderTest() {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ProfileBannerView(),
      ),
    );
  }

  group('ProfileBannerView', () {
    testWidgets(
      'renders title, subtitle, 3 banners, 6 colors, and continue button',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 2.5;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());

        expect(find.text('Profile Banner'), findsOneWidget);
        expect(
          find.text('Choose a preset style or pick a color'),
          findsOneWidget,
        );
        expect(find.byType(ProfileBannerItem), findsNWidgets(3));
        expect(find.byType(BannerColorItem), findsNWidgets(6));
        expect(find.byType(ProfileContinueButton), findsOneWidget);
      },
    );

    testWidgets(
      'Continue button activates when either banner or color is chosen, and only one is selected',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 2.5;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());

        var buttonWidget = tester.widget<ProfileContinueButton>(
          find.byType(ProfileContinueButton),
        );
        expect(buttonWidget.isEnabled, false);

        // Tap first banner (day)
        await tester.tap(find.byType(ProfileBannerItem).first);
        await tester.pump();

        buttonWidget = tester.widget<ProfileContinueButton>(
          find.byType(ProfileContinueButton),
        );
        expect(buttonWidget.isEnabled, true);

        var firstBanner = tester.widget<ProfileBannerItem>(
          find.byType(ProfileBannerItem).first,
        );
        expect(firstBanner.isSelected, true);

        // Tap 5th color (#B8DFE6) -> banner must be deselected, color selected
        await tester.tap(find.byType(BannerColorItem).at(4));
        await tester.pump();

        firstBanner = tester.widget<ProfileBannerItem>(
          find.byType(ProfileBannerItem).first,
        );
        expect(firstBanner.isSelected, false);

        final fifthColor = tester.widget<BannerColorItem>(
          find.byType(BannerColorItem).at(4),
        );
        expect(fifthColor.isSelected, true);

        buttonWidget = tester.widget<ProfileContinueButton>(
          find.byType(ProfileContinueButton),
        );
        expect(buttonWidget.isEnabled, true);
      },
    );

    testWidgets(
      'tapping active Continue button navigates to ProfileReadyView',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 2.5;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());

        // Select banner
        await tester.tap(find.byType(ProfileBannerItem).at(1));
        await tester.pump();

        // Select color
        await tester.tap(find.byType(BannerColorItem).first);
        await tester.pump();

        // Tap continue
        await tester.tap(find.byType(ProfileContinueButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text("You're all set!"), findsOneWidget);
        expect(
          find.text(
            "Don't worry, you can update this anytime in your profile!",
          ),
          findsOneWidget,
        );
      },
    );
  });
}
