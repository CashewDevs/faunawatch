import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/profile_customization/models/profile_setup_state.dart';

void main() {
  group('ProfileSetupState', () {
    test('initial state defaults to empty fields and disabled continue', () {
      const state = ProfileSetupState();
      expect(state.username, '');
      expect(state.bio, '');
      expect(state.isContinueEnabled, false);
      expect(state.isSubmitting, false);
      expect(state.errorMessage, isNull);
    });

    test('isContinueEnabled is false when only username is filled', () {
      const state = ProfileSetupState(username: 'FaunaExplorer');
      expect(state.isContinueEnabled, false);
    });

    test('isContinueEnabled is false when only bio is filled', () {
      const state = ProfileSetupState(bio: 'Nature enthusiast');
      expect(state.isContinueEnabled, false);
    });

    test(
      'isContinueEnabled is true when both username and bio are non-empty',
      () {
        const state = ProfileSetupState(
          username: 'FaunaExplorer',
          bio: 'Nature enthusiast',
        );
        expect(state.isContinueEnabled, true);
      },
    );

    test('copyWith properly updates specified properties', () {
      const initial = ProfileSetupState();
      final updated = initial.copyWith(
        username: 'RangerBob',
        bio: 'Wildlife protector',
        isSubmitting: true,
      );

      expect(updated.username, 'RangerBob');
      expect(updated.bio, 'Wildlife protector');
      expect(updated.isSubmitting, true);
      expect(updated.isContinueEnabled, true);
    });
  });
}
