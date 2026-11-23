import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_header_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = ProfileData(
    username: 'Forest wildlife observer',
    bio: 'Watching wildlife and protecting habitats together.',
    presetAvatar: AppAssets.avatarBunny,
    bannerAsset: AppAssets.bannerDay,
  );

  Future<void> pumpHeader(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1,
    VoidCallback? onMessage,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileHeaderCard(profile: profile, onMessage: onMessage),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('name and bio align beside the overlapping avatar', (
    tester,
  ) async {
    await pumpHeader(tester);

    final avatar = tester.getRect(
      find.byKey(const ValueKey('profile_header_avatar')),
    );
    final name = tester.getRect(find.text(profile.username));
    final bio = tester.getRect(find.text(profile.bio));
    expect(name.top, greaterThan(avatar.top));
    expect(name.top, lessThan(avatar.bottom));
    expect(name.left, greaterThan(avatar.right));
    expect(bio.top, greaterThan(name.bottom));
    expect(bio.left, name.left);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'public identity stays readable on a narrow ${dark ? 'dark' : 'light'} screen with large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var messages = 0;
        await pumpHeader(
          tester,
          dark: dark,
          scale: 2,
          onMessage: () => messages++,
        );

        final name = tester.getRect(find.text(profile.username));
        final bio = tester.getRect(find.text(profile.bio));
        final message = tester.getRect(
          find.byKey(const ValueKey('public_profile_message_button')),
        );
        final avatar = tester.getRect(
          find.byKey(const ValueKey('profile_header_avatar')),
        );
        expect(name.left, greaterThan(avatar.right));
        expect(bio.top, greaterThan(name.bottom));
        expect(bio.left, name.left);
        expect(message.top, greaterThan(bio.bottom));
        expect(message.left, name.left);
        for (final text in [profile.username, profile.bio, 'Message']) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(text),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: text);
        }
        final context = tester.element(find.byType(ProfileHeaderCard));
        expect(
          tester.widget<Text>(find.text(profile.username)).style!.color,
          Theme.of(context).colorScheme.onSurface,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Message'));
        expect(messages, 1);
      },
    );
  }
}
