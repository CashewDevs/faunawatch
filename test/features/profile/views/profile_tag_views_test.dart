import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/gallery/services/gallery_service.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/profile/models/profile_tag.dart';
import 'package:faunawatch/features/profile/services/profile_reader_service.dart';
import 'package:faunawatch/features/profile/services/profile_tag_service.dart';
import 'package:faunawatch/features/profile/views/profile_view.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_header_card.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_tag_sheet.dart';
import 'package:faunawatch/features/suspension/services/suspension_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../gallery/fake_gallery_service.dart';

class _Tags implements ProfileTagService {
  ProfileTagActivity activity = const ProfileTagActivity(
    approvedReports: 3,
    dogReports: 2,
    catReports: 0,
  );
  bool succeeds = true;
  bool throwsOnLoad = false;
  int reads = 0;
  final writes = <ProfileTag?>[];

  @override
  Future<ProfileTagActivity> fetchActivity() async {
    reads++;
    if (throwsOnLoad) throw StateError('Unavailable');
    return activity;
  }

  @override
  Future<bool> saveTag(ProfileTag? tag) async {
    writes.add(tag);
    return succeeds;
  }
}

class _Reader implements ProfileReaderService {
  _Reader(this.tag);
  final ProfileTag? tag;
  @override
  Future<ProfileData> loadProfile(String userId) async => ProfileData(
    username: 'Ranger',
    bio: 'Watching wildlife responsibly.',
    presetAvatar: AppAssets.avatarBunny,
    profileTag: tag,
  );
}

void main() {
  late _Tags service;
  setUp(() => service = _Tags());

  Future<void> pump(
    WidgetTester tester, {
    ProfileTag? tag,
    bool dark = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(scale > 1 ? 320 : 390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => Stream.value('user-a')),
          profileReaderServiceProvider.overrideWithValue(_Reader(tag)),
          profileTagServiceProvider.overrideWithValue(service),
          galleryServiceProvider.overrideWithValue(FakeGalleryService()),
          suspensionServiceProvider.overrideWithValue(
            const SignedOutSuspensionService(),
          ),
        ],
        child: MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const ProfileView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, {bool hasTag = false}) async {
    final action = hasTag
        ? find.byTooltip('Edit profile tag')
        : find.byKey(const ValueKey('add_profile_tag'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  Finder headerTag(String label) => find.descendant(
    of: find.byType(ProfileHeaderCard),
    matching: find.text(label),
  );

  testWidgets('suggestions appear only on request and require confirmation', (
    tester,
  ) async {
    await pump(tester);
    expect(service.reads, 0);
    await open(tester);
    expect(find.text('Suggested for you'), findsOneWidget);
    expect(headerTag('Dog Lover'), findsNothing);
    expect(service.writes, isEmpty);
    await tester.tap(find.byTooltip('Close profile tags'));
    await tester.pumpAndSettle();
    expect(headerTag('Dog Lover'), findsNothing);

    await open(tester);
    await tester.tap(find.text('Use Dog Lover'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileTagSheet), findsNothing);
    expect(headerTag('Dog Lover'), findsOneWidget);
    expect(service.writes, [ProfileTag.dogLover]);
    expect(
      tester.getRect(headerTag('Dog Lover')).top,
      greaterThan(
        tester.getRect(find.text('Watching wildlife responsibly.')).bottom,
      ),
    );
  });

  testWidgets('before three approvals the sheet shows progress without a tag', (
    tester,
  ) async {
    service.activity = const ProfileTagActivity(
      approvedReports: 2,
      dogReports: 2,
      catReports: 0,
    );
    await pump(tester);
    await open(tester);
    expect(find.text('2 of 3 approved reports'), findsOneWidget);
    expect(
      find.text(
        'Your first suggestion becomes available after 3 '
        'approved reports. Unposted scans do not count.',
      ),
      findsOneWidget,
    );
    expect(find.text('Use Dog Lover'), findsNothing);
    expect(service.writes, isEmpty);
  });

  testWidgets(
    'failed confirmation retains the tag; successful removal clears it',
    (tester) async {
      service.succeeds = false;
      await pump(tester, tag: ProfileTag.catLover);
      await open(tester, hasTag: true);
      await tester.tap(find.text('Use Dog Lover'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile_tag_error')), findsOneWidget);
      expect(headerTag('Cat Lover'), findsOneWidget);
      expect(headerTag('Dog Lover'), findsNothing);
      service.succeeds = true;
      await tester.tap(find.text('Remove tag'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileTagSheet), findsNothing);
      expect(headerTag('Cat Lover'), findsNothing);
      expect(service.writes, [ProfileTag.dogLover, null]);
      expect(find.text('Add profile tag'), findsOneWidget);
    },
  );

  testWidgets(
    'a narrow dark sheet with large text scrolls through errors and retry',
    (tester) async {
      service.throwsOnLoad = true;
      await pump(tester, dark: true, scale: 2);
      await open(tester);
      expect(find.byKey(const ValueKey('profile_tag_error')), findsOneWidget);
      service.throwsOnLoad = false;
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Use Dog Lover'));
      expect(tester.takeException(), isNull);
      expect(service.writes, isEmpty);
    },
  );
}
