import 'dart:async';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/profile/models/profile_tag.dart';
import 'package:faunawatch/features/profile/services/profile_reader_service.dart';
import 'package:faunawatch/features/profile/services/profile_tag_service.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_tag_viewmodel.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';
import 'package:faunawatch/features/suspension/models/account_suspension.dart';
import 'package:faunawatch/features/suspension/viewmodels/account_suspension_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const dogs = ProfileTagActivity(
  approvedReports: 5,
  dogReports: 3,
  catReports: 0,
);
const mixed = ProfileTagActivity(
  approvedReports: 6,
  dogReports: 2,
  catReports: 2,
);

class _Tags implements ProfileTagService {
  ProfileTagActivity activity = dogs;
  bool succeeds = true;
  bool throwsOnLoad = false;
  final writes = <ProfileTag?>[];
  Completer<bool>? pendingSave;
  Completer<ProfileTagActivity>? pendingLoad;

  @override
  Future<ProfileTagActivity> fetchActivity() async {
    if (throwsOnLoad) throw StateError('Unavailable');
    return pendingLoad?.future ?? activity;
  }

  @override
  Future<bool> saveTag(ProfileTag? tag) async {
    writes.add(tag);
    return pendingSave?.future ?? succeeds;
  }
}

class _Reader implements ProfileReaderService {
  ProfileTag? tag;
  @override
  Future<ProfileData> loadProfile(String userId) async =>
      ProfileData(username: userId, bio: 'Saved bio', profileTag: tag);
}

class _Suspension extends AccountSuspensionViewModel {
  @override
  AccountSuspension? build() => null;
  void suspend() => state = AccountSuspension(
    id: 'suspension',
    level: SuspensionLevel.restricted,
    message: 'Please review the rules.',
    startedAt: DateTime.utc(2026, 11, 23),
  );
}

void main() {
  late _Tags service;
  late _Reader reader;
  late ProviderContainer container;
  late void Function() closeTags;

  Future<void> settle() async {
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();
  }

  Future<void> start({Stream<String?>? accounts}) async {
    container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith(
          (ref) => accounts ?? Stream.value('user-a'),
        ),
        profileTagServiceProvider.overrideWith((ref) {
          ref.watch(currentUserIdProvider);
          return service;
        }),
        profileReaderServiceProvider.overrideWithValue(reader),
        accountSuspensionViewModelProvider.overrideWith(_Suspension.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(currentUserIdProvider.future);
    await container.read(profileViewModelProvider.future);
    final subscription = container.listen(
      profileTagViewModelProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    closeTags = subscription.close;
    await settle();
  }

  setUp(() {
    service = _Tags();
    reader = _Reader();
  });

  test(
    'loading suggestions never assigns a tag; confirmation persists it',
    () async {
      await start();
      expect(
        container.read(profileTagViewModelProvider).activity?.suggestions,
        [ProfileTag.dogLover],
      );
      expect(service.writes, isEmpty);
      expect(
        container.read(profileViewModelProvider).requireValue.profileTag,
        isNull,
      );
      expect(
        await container
            .read(profileTagViewModelProvider.notifier)
            .confirm(ProfileTag.dogLover),
        isTrue,
      );
      expect(service.writes, [ProfileTag.dogLover]);
      final profile = container.read(profileViewModelProvider).requireValue;
      expect(profile.profileTag, ProfileTag.dogLover);
      expect(profile.bio, 'Saved bio');
    },
  );

  test('unqualified tags and duplicate submissions are rejected', () async {
    await start();
    final vm = container.read(profileTagViewModelProvider.notifier);
    expect(await vm.confirm(ProfileTag.catLover), isFalse);
    expect(service.writes, isEmpty);
    service.pendingSave = Completer<bool>();
    final save = vm.confirm(ProfileTag.dogLover);
    expect(await vm.confirm(ProfileTag.dogLover), isFalse);
    expect(service.writes, hasLength(1));
    service.pendingSave!.complete(true);
    expect(await save, isTrue);
  });

  test(
    'closing suggestions during a confirmed save still updates the profile',
    () async {
      await start();
      service.pendingSave = Completer<bool>();
      final save = container
          .read(profileTagViewModelProvider.notifier)
          .confirm(ProfileTag.dogLover);
      closeTags();
      await settle();
      service.pendingSave!.complete(true);
      expect(await save, isTrue);
      expect(
        container.read(profileViewModelProvider).requireValue.profileTag,
        ProfileTag.dogLover,
      );
    },
  );

  test('failed saves and removals retain the existing public tag', () async {
    reader.tag = ProfileTag.catLover;
    await start();
    service.succeeds = false;
    final vm = container.read(profileTagViewModelProvider.notifier);
    expect(await vm.confirm(ProfileTag.dogLover), isFalse);
    expect(
      container.read(profileViewModelProvider).requireValue.profileTag,
      ProfileTag.catLover,
    );
    expect(container.read(profileTagViewModelProvider).errorMessage, isNotNull);
    expect(await vm.remove(), isFalse);
    expect(
      container.read(profileViewModelProvider).requireValue.profileTag,
      ProfileTag.catLover,
    );
    service.succeeds = true;
    expect(await vm.remove(), isTrue);
    expect(
      container.read(profileViewModelProvider).requireValue.profileTag,
      isNull,
    );
  });

  test('refreshing activity preserves a previously confirmed tag', () async {
    reader.tag = ProfileTag.dogLover;
    await start();
    service.activity = mixed;
    await container.read(profileTagViewModelProvider.notifier).retry();
    expect(container.read(profileTagViewModelProvider).activity?.suggestions, [
      ProfileTag.spotter,
    ]);
    expect(
      container.read(profileViewModelProvider).requireValue.profileTag,
      ProfileTag.dogLover,
    );
    expect(service.writes, isEmpty);
  });

  test('a failed activity load can be retried', () async {
    service.throwsOnLoad = true;
    await start();
    expect(container.read(profileTagViewModelProvider).errorMessage, isNotNull);
    service.throwsOnLoad = false;
    await container.read(profileTagViewModelProvider.notifier).retry();
    expect(container.read(profileTagViewModelProvider).activity, dogs);
    expect(container.read(profileTagViewModelProvider).errorMessage, isNull);
  });

  test('suspension after opening blocks confirmation and removal', () async {
    await start();
    (container.read(accountSuspensionViewModelProvider.notifier) as _Suspension)
        .suspend();
    final vm = container.read(profileTagViewModelProvider.notifier);
    expect(await vm.confirm(ProfileTag.dogLover), isFalse);
    expect(await vm.remove(), isFalse);
    expect(service.writes, isEmpty);
    expect(
      container.read(profileTagViewModelProvider).errorMessage,
      contains('profile'),
    );
  });

  test('a stale save cannot set another account\'s public tag', () async {
    final accounts = StreamController<String?>();
    addTearDown(accounts.close);
    final starting = start(accounts: accounts.stream);
    accounts.add('user-a');
    await starting;
    service.pendingSave = Completer<bool>();
    final save = container
        .read(profileTagViewModelProvider.notifier)
        .confirm(ProfileTag.dogLover);
    accounts.add('user-b');
    await settle();
    await container.read(profileViewModelProvider.future);
    service.pendingSave!.complete(true);
    expect(await save, isFalse);
    final profile = container.read(profileViewModelProvider).requireValue;
    expect(profile.username, 'user-b');
    expect(profile.profileTag, isNull);
  });

  test(
    'a stale activity request cannot replace newer account suggestions',
    () async {
      final accounts = StreamController<String?>();
      addTearDown(accounts.close);
      service.pendingLoad = Completer<ProfileTagActivity>();
      final oldLoad = service.pendingLoad!;
      final starting = start(accounts: accounts.stream);
      accounts.add('user-a');
      await starting;
      service.pendingLoad = null;
      service.activity = mixed;
      accounts.add('user-b');
      await settle();
      oldLoad.complete(dogs);
      await settle();
      expect(container.read(profileTagViewModelProvider).activity, mixed);
    },
  );
}
