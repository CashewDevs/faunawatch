import 'dart:async';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/profile_customization/services/profile_service.dart';
import '../fake_profile_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/profile/services/profile_reader_service.dart';
import 'package:faunawatch/features/profile/services/profile_storage_service.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';

class FakeProfileReader implements ProfileReaderService {
  final requests = <String>[];
  Future<ProfileData> Function(String)? load;

  @override
  Future<ProfileData> loadProfile(String userId) async {
    requests.add(userId);
    return load != null ? load!(userId) : const ProfileData(username: 'Tester');
  }
}

void main() {
  late FakeProfileReader reader;
  late FakeProfileService writer;
  late ProviderContainer container;
  late StreamController<String?> users;
  setUp(() {
    reader = FakeProfileReader();
    writer = FakeProfileService();
    users = StreamController<String?>();
    container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => users.stream),
        profileReaderServiceProvider.overrideWithValue(reader),
        profileServiceProvider.overrideWithValue(writer),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await users.close();
  });

  test('loads persisted profile instead of sample content', () async {
    final result = container.read(profileViewModelProvider.future);
    users.add('user-a');
    final profile = await result;
    expect(reader.requests, ['user-a']);
    expect(profile.username, 'Tester');
    expect(profile.bio, isEmpty);
  });

  test('clears the profile on sign-out and loads the next account', () async {
    final subscription = container.listen(profileViewModelProvider, (_, _) {});
    addTearDown(subscription.close);
    users.add('user-a');
    await container.read(profileViewModelProvider.future);
    users.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(
      (await container.read(profileViewModelProvider.future)).username,
      '',
    );
    users.add('user-b');
    await Future<void>.delayed(Duration.zero);
    await container.read(profileViewModelProvider.future);
    expect(reader.requests, ['user-a', 'user-b']);
  });

  test('reports load failures and supports retry', () async {
    reader.load = (_) async => throw StateError('Unavailable');
    final result = container.read(profileViewModelProvider.future);
    users.add('user-a');
    await expectLater(result, throwsStateError);
    expect(container.read(profileViewModelProvider).hasError, isTrue);
    reader.load = (_) async => const ProfileData(username: 'Recovered');
    container.invalidate(profileViewModelProvider);
    expect(
      (await container.read(profileViewModelProvider.future)).username,
      'Recovered',
    );
  });

  test(
    'updateProfile updates loaded state and save delegates to storage',
    () async {
      final result = container.read(profileViewModelProvider.future);
      users.add('user-a');
      await result;
      final notifier = container.read(profileViewModelProvider.notifier);
      notifier.updateProfile(
        username: 'nature_watcher',
        bio: 'Wildlife enthusiast',
        bannerAsset: AppAssets.bannerNight,
      );
      expect(
        container.read(profileViewModelProvider).requireValue.username,
        'nature_watcher',
      );
      // The existing edit persistence contract is unchanged by profile loading.
      expect(
        container.read(profileStorageServiceProvider),
        isA<ProfileStorageService>(),
      );
      expect(await notifier.save(), isTrue);
      expect(writer.savedBanner, AppAssets.bannerNight);
      expect(writer.savedColor, isNull);
      notifier.updateProfile(bannerColorValue: 0xFFBCE7B4, clearBanner: true);
      expect(await notifier.save(), isTrue);
      expect(writer.savedBanner, isNull);
      expect(writer.savedColor, 0xFFBCE7B4);
      writer.succeeds = false;
      expect(await notifier.save(), isFalse);
      writer.throwsOnSave = true;
      expect(await notifier.save(), isFalse);
    },
  );
}
