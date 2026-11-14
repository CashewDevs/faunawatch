import 'package:faunawatch/core/theme/theme_provider.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/feed/views/widgets/feed_tab_bar.dart';
import 'package:faunawatch/features/shell/views/widgets/shell_header.dart';
import 'package:faunawatch/features/messages/views/widgets/messages_header.dart';
import 'package:faunawatch/features/profile/models/theme_palette.dart';
import 'package:faunawatch/features/profile/viewmodels/settings_viewmodel.dart';
import 'package:faunawatch/features/profile/views/widgets/theme_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return first > second
      ? (first + 0.05) / (second + 0.05)
      : (second + 0.05) / (first + 0.05);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'every palette updates both theme variants independently of mode',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final settings = container.read(settingsViewModelProvider.notifier);
      expect(
        container.read(activeThemePaletteProvider),
        AppThemePalette.apollo,
      );
      expect(AppThemePalette.presets, hasLength(6));
      final lightColors = <Color>{};
      final darkColors = <Color>{};
      for (final mode in ThemeMode.values) {
        container.read(themeModeProvider.notifier).setThemeMode(mode);
        for (final palette in AppThemePalette.presets) {
          settings.setPalette(palette.id);
          expect(container.read(themeModeProvider), mode);
          expect(container.read(activeThemePaletteProvider), palette);
          for (final provider in [
            appLightThemeProvider,
            appDarkThemeProvider,
          ]) {
            final theme = container.read(provider);
            final scheme = theme.colorScheme;
            expect(
              contrast(scheme.primary, scheme.onPrimary),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              contrast(scheme.primaryContainer, scheme.onPrimaryContainer),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              contrast(scheme.secondaryContainer, scheme.onSecondaryContainer),
              greaterThanOrEqualTo(4.5),
            );
            if (provider == appLightThemeProvider) {
              expect(theme.brightness, Brightness.light);
              lightColors.add(scheme.primary);
            } else {
              expect(theme.brightness, Brightness.dark);
              darkColors.add(scheme.primary);
            }
          }
        }
      }
      expect(lightColors, hasLength(5));
      expect(darkColors, hasLength(5));
      settings.setPalette('unknown');
      expect(container.read(activeThemePaletteProvider).id, 'meadow');
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'Apollo restores the original headers and yellow accents in both modes',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      for (final provider in [appLightThemeProvider, appDarkThemeProvider]) {
        final theme = container.read(provider);
        final colors = theme.extension<AppPaletteColors>()!;
        expect(
          colors.profileButtonGradientStart,
          AppColors.profileButtonGradientStart,
        );
        expect(
          colors.profileButtonGradientEnd,
          AppColors.profileButtonGradientEnd,
        );
        expect(colors.navActiveBackground, AppColors.navActiveBackground);
        expect(
          colors.galleryCardDetailsYellow,
          AppColors.galleryCardDetailsYellow,
        );
        final originalScheme = ColorScheme.fromSeed(
          seedColor: AppColors.primarySeed,
          brightness: theme.brightness,
        );
        expect(theme.colorScheme.primary, originalScheme.primary);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Column(
                  children: [
                    const ShellHeader(),
                    const MessagesHeader(),
                    FeedTabBar(selected: FeedTab.forYou, onSelect: (_) {}),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final header = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(ShellHeader),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(header.color, AppColors.shellHeaderBlue);
        final messages = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(MessagesHeader),
                matching: find.byType(Container),
              )
              .first,
        );
        final gradient =
            (messages.decoration! as BoxDecoration).gradient! as LinearGradient;
        expect(
          gradient.colors,
          theme.brightness == Brightness.dark
              ? [
                  AppColors.darkHeaderGradientStart,
                  AppColors.darkHeaderGradientEnd,
                ]
              : [
                  AppColors.messagesHeaderGradientStart,
                  AppColors.messagesHeaderGradientEnd,
                ],
        );
        expect(
          find.descendant(
            of: find.byType(FeedTabBar),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration! as BoxDecoration).color ==
                      AppColors.messagesHeaderUnderline,
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      container.read(settingsViewModelProvider.notifier).setPalette('ocean');
      final ocean = container.read(appLightThemeProvider);
      expect(
        ocean.extension<AppPaletteColors>()!.shellHeaderBlue,
        ocean.colorScheme.primary,
      );
      container.read(settingsViewModelProvider.notifier).setPalette('apollo');
      expect(
        container
            .read(appLightThemeProvider)
            .extension<AppPaletteColors>()!
            .shellHeaderBlue,
        AppColors.shellHeaderBlue,
      );
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  for (final mode in [ThemeMode.light, ThemeMode.dark, ThemeMode.system]) {
    testWidgets('picker applies every palette and preserves $mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeModeProvider.notifier).setThemeMode(mode);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              theme: ref.watch(appLightThemeProvider),
              darkTheme: ref.watch(appDarkThemeProvider),
              themeMode: ref.watch(themeModeProvider),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.5)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const ThemePickerSheet(),
                      ),
                      child: const Text('Choose palette'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (final palette in AppThemePalette.presets) {
        await tester.tap(find.text('Choose palette'));
        await tester.pumpAndSettle();
        final expected = container.read(
          mode == ThemeMode.light
              ? appLightThemeProvider
              : appDarkThemeProvider,
        );
        final pickerScheme = Theme.of(
          tester.element(find.byType(ThemePickerSheet)),
        ).colorScheme;
        expect(pickerScheme.brightness, expected.brightness);
        final option = find.text(palette.name);
        await tester.scrollUntilVisible(
          option,
          120,
          scrollable: find.descendant(
            of: find.byType(ThemePickerSheet),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(option);
        await tester.pumpAndSettle();
        expect(find.byType(ThemePickerSheet), findsNothing);
        expect(
          container.read(settingsViewModelProvider).activePaletteId,
          palette.id,
        );
        expect(container.read(themeModeProvider), mode);
        final actual = Theme.of(tester.element(find.text('Choose palette')));
        final selected = container.read(
          mode == ThemeMode.light
              ? appLightThemeProvider
              : appDarkThemeProvider,
        );
        expect(actual.colorScheme.primary, selected.colorScheme.primary);
        expect(tester.takeException(), isNull);
      }
      if (mode == ThemeMode.system) {
        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        await tester.pumpAndSettle();
        final actual = Theme.of(tester.element(find.text('Choose palette')));
        expect(actual.brightness, Brightness.light);
        expect(
          actual.colorScheme.primary,
          container.read(appLightThemeProvider).colorScheme.primary,
        );
        expect(container.read(activeThemePaletteProvider).id, 'meadow');
      }
    });
  }
}
