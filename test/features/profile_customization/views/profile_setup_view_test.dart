import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/profile_customization/views/profile_setup_view.dart';
import 'package:faunawatch/features/profile_customization/views/widgets/profile_continue_button.dart';

void main() {
  Widget createWidgetUnderTest() {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ProfileSetupView(),
      ),
    );
  }

  group('ProfileSetupView', () {
    testWidgets('renders header, inputs, labels, and continue button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('What should we\ncall you?'), findsOneWidget);
      expect(find.text('Add a Bio!'), findsOneWidget);
      expect(find.text('0/20 characters'), findsOneWidget);
      expect(find.text('0/50 characters'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byType(ProfileContinueButton), findsOneWidget);
    });

    testWidgets(
      'Continue button activates only when both username and bio are typed on',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 2.5;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());

        final buttonFinder = find.byType(ProfileContinueButton);
        var buttonWidget = tester.widget<ProfileContinueButton>(buttonFinder);
        expect(buttonWidget.isEnabled, false);

        final textFields = find.byType(TextField);

        // Enter username only
        await tester.enterText(textFields.first, 'WoodlandRanger');
        await tester.pump();

        buttonWidget = tester.widget<ProfileContinueButton>(buttonFinder);
        expect(buttonWidget.isEnabled, false);
        expect(find.text('14/20 characters'), findsOneWidget);

        // Enter bio
        await tester.enterText(textFields.last, 'Protecting birds and deer.');
        await tester.pump();

        buttonWidget = tester.widget<ProfileContinueButton>(buttonFinder);
        expect(buttonWidget.isEnabled, true);
        expect(find.text('26/50 characters'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping enabled Continue button completes and navigates to ProfilePictureView',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 2.5;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'WoodlandRanger');
        await tester.enterText(textFields.last, 'Protecting birds and deer.');
        await tester.pump();

        await tester.tap(find.byType(ProfileContinueButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('Your Profile Picture'), findsOneWidget);
        expect(
          find.text('Select a spotter icon or upload a custom image.'),
          findsOneWidget,
        );
      },
    );
  });
}
