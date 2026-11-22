import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/profile/services/password_service.dart';
import 'package:faunawatch/features/profile/viewmodels/change_password_viewmodel.dart';

class _FakePasswordService implements PasswordService {
  String? lastCurrent;
  String? lastNew;
  int resetCalls = 0;
  Object? changeError;
  Object? resetError;
  String resetEmail = 'spotter@example.com';

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (changeError != null) throw changeError!;
    lastCurrent = currentPassword;
    lastNew = newPassword;
  }

  @override
  Future<String> sendPasswordResetEmail() async {
    resetCalls++;
    if (resetError != null) throw resetError!;
    return resetEmail;
  }
}

void main() {
  late _FakePasswordService service;
  late ProviderContainer container;

  setUp(() {
    service = _FakePasswordService();
    container = ProviderContainer(
      overrides: [passwordServiceProvider.overrideWithValue(service)],
    );
  });

  tearDown(() => container.dispose());

  group('ChangePasswordViewModel', () {
    test('tracks password requirements live', () {
      final sub = container.listen(changePasswordViewModelProvider, (_, _) {});
      addTearDown(sub.close);
      final notifier = container.read(changePasswordViewModelProvider.notifier);

      expect(
        container.read(changePasswordViewModelProvider).allRequirementsMet,
        isFalse,
      );

      notifier.setNewPassword('short1');
      expect(
        container.read(changePasswordViewModelProvider).hasMinLength,
        isFalse,
      );
      expect(
        container.read(changePasswordViewModelProvider).hasLetterAndNumber,
        isTrue,
      );

      notifier.setNewPassword('longpassword');
      expect(
        container.read(changePasswordViewModelProvider).hasMinLength,
        isTrue,
      );
      expect(
        container.read(changePasswordViewModelProvider).hasLetterAndNumber,
        isFalse,
      );

      notifier.setNewPassword('Wildlife1');
      notifier.setConfirmPassword('Wildlife1');
      final ready = container.read(changePasswordViewModelProvider);
      expect(ready.hasMinLength, isTrue);
      expect(ready.hasLetterAndNumber, isTrue);
      expect(ready.matchesConfirmation, isTrue);
      expect(ready.allRequirementsMet, isTrue);
    });

    test('rejects invalid inputs before calling PasswordService', () async {
      final sub = container.listen(changePasswordViewModelProvider, (_, _) {});
      addTearDown(sub.close);
      final notifier = container.read(changePasswordViewModelProvider.notifier);

      expect(await notifier.submit(), isFalse);
      expect(
        container.read(changePasswordViewModelProvider).errorMessage,
        'Please enter your current password.',
      );

      notifier.setCurrentPassword('OldPass1');
      notifier.setNewPassword('OldPass1');
      notifier.setConfirmPassword('OldPass1');
      expect(await notifier.submit(), isFalse);
      expect(
        container.read(changePasswordViewModelProvider).errorMessage,
        'New password must be different from your current password.',
      );
      expect(service.lastNew, isNull);
    });

    test('submits valid password change and surfaces AuthException', () async {
      final sub = container.listen(changePasswordViewModelProvider, (_, _) {});
      addTearDown(sub.close);
      final notifier = container.read(changePasswordViewModelProvider.notifier);

      notifier.setCurrentPassword('OldPass1');
      notifier.setNewPassword('NewPass2');
      notifier.setConfirmPassword('NewPass2');

      expect(await notifier.submit(), isTrue);
      expect(service.lastCurrent, 'OldPass1');
      expect(service.lastNew, 'NewPass2');

      service.changeError = const AuthException(
        'Current password is incorrect.',
      );
      expect(await notifier.submit(), isFalse);
      expect(
        container.read(changePasswordViewModelProvider).errorMessage,
        'Current password is incorrect.',
      );
    });

    test('sends password reset email and sets confirmation message', () async {
      final sub = container.listen(changePasswordViewModelProvider, (_, _) {});
      addTearDown(sub.close);
      final notifier = container.read(changePasswordViewModelProvider.notifier);

      expect(await notifier.sendResetEmail(), isTrue);
      expect(service.resetCalls, 1);
      expect(
        container.read(changePasswordViewModelProvider).infoMessage,
        'Password reset link sent to spotter@example.com.',
      );
    });
  });
}
