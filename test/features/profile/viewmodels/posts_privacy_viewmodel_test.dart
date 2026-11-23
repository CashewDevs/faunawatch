import 'dart:async';

import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/profile/services/posts_privacy_service.dart';
import 'package:faunawatch/features/profile/viewmodels/posts_privacy_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Privacy implements PostsPrivacyService {
  bool saved = false;
  Object? loadError, saveError;
  Completer<bool>? pendingSave;
  int loads = 0;
  final saves = <bool>[];

  @override
  Future<bool> load() async {
    ++loads;
    if (loadError != null) throw loadError!;
    return saved;
  }

  @override
  Future<bool> save(bool isPrivate) async {
    saves.add(isPrivate);
    if (pendingSave != null) return pendingSave!.future;
    if (saveError != null) throw saveError!;
    return saved = isPrivate;
  }
}

void main() {
  late _Privacy privacy;
  late ProviderContainer container;
  late StreamController<String?> user;

  setUp(() {
    privacy = _Privacy();
    user = StreamController<String?>.broadcast();
    container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => user.stream),
        postsPrivacyServiceProvider.overrideWithValue(privacy),
      ],
    );
    // Keep the auto-dispose provider alive, as the Settings screen does.
    container.listen(postsPrivacyViewModelProvider, (_, _) {});
  });
  tearDown(() {
    container.dispose();
    user.close();
  });

  Future<void> signIn(String id) async {
    user.add(id);
    await pumpEventQueue();
  }

  test('signed out shows an off switch and loads nothing', () async {
    await pumpEventQueue();
    final state = container.read(postsPrivacyViewModelProvider);
    expect(state.isPrivate, isFalse);
    expect(state.isLoading, isFalse);
    expect(privacy.loads, 0);
  });

  test('loads the saved setting after sign-in', () async {
    privacy.saved = true;
    await signIn('user-a');
    final state = container.read(postsPrivacyViewModelProvider);
    expect(state.isPrivate, isTrue);
    expect(state.canChange, isTrue);
  });

  test(
    'a change moves the switch at once and blocks a second change',
    () async {
      await signIn('user-a');
      privacy.pendingSave = Completer<bool>();
      final vm = container.read(postsPrivacyViewModelProvider.notifier);

      final saving = vm.setPrivate(true);
      var state = container.read(postsPrivacyViewModelProvider);
      expect(state.isPrivate, isTrue);
      expect(state.isSaving, isTrue);
      expect(state.canChange, isFalse);
      await vm.setPrivate(false);
      expect(privacy.saves, [true]);

      privacy.pendingSave!.complete(true);
      await saving;
      state = container.read(postsPrivacyViewModelProvider);
      expect(state.isPrivate, isTrue);
      expect(state.isSaving, isFalse);
    },
  );

  test('a failed save moves the switch back with a message', () async {
    await signIn('user-a');
    privacy.saveError = StateError('offline');
    final vm = container.read(postsPrivacyViewModelProvider.notifier);

    await vm.setPrivate(true);
    var state = container.read(postsPrivacyViewModelProvider);
    expect(state.isPrivate, isFalse);
    expect(state.message, PostsPrivacyViewModel.saveFailedMessage);

    vm.clearMessage();
    state = container.read(postsPrivacyViewModelProvider);
    expect(state.message, isNull);
  });

  test('a failed load blocks changes until a retry succeeds', () async {
    privacy.loadError = StateError('offline');
    await signIn('user-a');
    final vm = container.read(postsPrivacyViewModelProvider.notifier);
    expect(container.read(postsPrivacyViewModelProvider).loadFailed, isTrue);

    await vm.setPrivate(true);
    expect(privacy.saves, isEmpty);

    privacy
      ..loadError = null
      ..saved = true;
    await vm.retry();
    final state = container.read(postsPrivacyViewModelProvider);
    expect(state.loadFailed, isFalse);
    expect(state.isPrivate, isTrue);
  });

  test('switching accounts reloads the setting for the new account', () async {
    privacy.saved = true;
    await signIn('user-a');
    expect(container.read(postsPrivacyViewModelProvider).isPrivate, isTrue);

    privacy.saved = false;
    await signIn('user-b');
    expect(container.read(postsPrivacyViewModelProvider).isPrivate, isFalse);
    expect(privacy.loads, 2);
  });
}
