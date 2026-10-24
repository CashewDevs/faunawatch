import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';

void main() {
  group('ProfileViewModel', () {
    test('initial state defaults to tweetybird and custom bio', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(profileViewModelProvider);
      expect(state.username, 'tweetybird');
      expect(state.bio, 'pls dont be inluv wt sum1 else');
      expect(state.bannerColorValue, 0xFFBCE7B4);
    });

    test('updateProfile updates state in memory', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(profileViewModelProvider.notifier);
      notifier.updateProfile(
        username: 'nature_watcher',
        bio: 'Wildlife enthusiast',
        bannerColorValue: 0xFFA4DDFF,
      );

      final state = container.read(profileViewModelProvider);
      expect(state.username, 'nature_watcher');
      expect(state.bio, 'Wildlife enthusiast');
      expect(state.bannerColorValue, 0xFFA4DDFF);
    });

    test('save delegates to service and succeeds', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(profileViewModelProvider.notifier);
      final result = await notifier.save();
      expect(result, isTrue);
    });
  });
}
