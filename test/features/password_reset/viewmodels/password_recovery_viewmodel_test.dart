import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/password_reset/models/password_recovery_state.dart';
import 'package:faunawatch/features/password_reset/services/password_reset_service.dart';
import 'package:faunawatch/features/password_reset/viewmodels/password_recovery_viewmodel.dart';
import '../fake_password_reset_service.dart';

void main() {
  late FakePasswordResetService service;
  late FakeAuthService auth;
  late ProviderContainer container;

  PasswordRecoveryState read() =>
      container.read(passwordRecoveryViewModelProvider);
  PasswordRecoveryViewModel vm() =>
      container.read(passwordRecoveryViewModelProvider.notifier);

  void typeValidPassword() {
    vm().setNewPassword('newpass123');
    vm().setConfirmPassword('newpass123');
  }

  setUp(() {
    service = FakePasswordResetService();
    auth = FakeAuthService();
    container = ProviderContainer(
      overrides: [
        passwordResetServiceProvider.overrideWithValue(service),
        authServiceProvider.overrideWithValue(auth),
      ],
    );
    container.listen(passwordRecoveryViewModelProvider, (_, _) {});
  });
  tearDown(() async {
    container.dispose();
    await service.dispose();
  });

  test('idle until a link opens the app', () {
    expect(read().stage, RecoveryStage.idle);
  });

  test('an opened link asks for a new password for that account', () {
    service.links.add(ResetLinkEvent.opened);
    expect(read().stage, RecoveryStage.choosing);
    expect(read().email, 'spotter@example.com');
  });

  test('a failed link says so', () {
    service.links.add(ResetLinkEvent.failed);
    expect(read().stage, RecoveryStage.linkFailed);
  });

  test('save sets the password, keeps the user signed in', () async {
    service.links.add(ResetLinkEvent.opened);
    typeValidPassword();
    await vm().save();

    expect(service.savedPasswords, ['newpass123']);
    expect(read().stage, RecoveryStage.saved);
    expect(auth.signOuts, 0);

    vm().finish();
    expect(read().stage, RecoveryStage.idle);
  });

  test('save does nothing until every rule is met', () async {
    service.links.add(ResetLinkEvent.opened);
    vm().setNewPassword('short1');
    vm().setConfirmPassword('short1');
    await vm().save();
    expect(service.savedPasswords, isEmpty);
    expect(read().stage, RecoveryStage.choosing);
  });

  final errors = <String, Object>{
    "That's your current password. Choose a different one.":
        const AuthApiException(
          'New password should be different from the old password.',
          statusCode: '422',
          code: 'same_password',
        ),
    'That password is too easy to guess. Choose a stronger one.':
        const AuthApiException(
          'weak',
          statusCode: '422',
          code: 'weak_password',
        ),
    "Can't reach FaunaWatch. Check your internet connection and try again.":
        AuthRetryableFetchException(),
    'This reset has ended. Ask for a new link from the login screen.':
        AuthSessionMissingException(),
    "We couldn't save your new password. Please try again.": StateError(
      'secret server detail',
    ),
  };
  errors.forEach((message, error) {
    test(
      'a refused save shows a safe message and can be retried: $error',
      () async {
        service.links.add(ResetLinkEvent.opened);
        typeValidPassword();
        service.saveError = error;
        await vm().save();
        expect(read().stage, RecoveryStage.choosing);
        expect(read().errorMessage, message);
        expect(read().isBusy, isFalse);

        service.saveError = null;
        await vm().save();
        expect(read().stage, RecoveryStage.saved);
      },
    );
  });

  test('cancel signs out and returns to the app', () async {
    service.links.add(ResetLinkEvent.opened);
    await vm().cancel();
    expect(auth.signOuts, 1);
    expect(read().stage, RecoveryStage.idle);
  });

  test('cancel that cannot sign out stays and explains', () async {
    service.links.add(ResetLinkEvent.opened);
    auth.signOutError = AuthRetryableFetchException();
    await vm().cancel();
    expect(read().stage, RecoveryStage.choosing);
    expect(read().errorMessage, contains("Couldn't log you out"));
  });

  test('a link event while saving does not interrupt the save', () async {
    service.links.add(ResetLinkEvent.opened);
    typeValidPassword();
    service.pendingSave = Completer<void>();
    final saving = vm().save();
    service.links.add(ResetLinkEvent.failed);
    expect(read().stage, RecoveryStage.choosing);
    service.pendingSave!.complete();
    await saving;
    expect(read().stage, RecoveryStage.saved);
  });

  test('finish only closes the end screens', () {
    service.links.add(ResetLinkEvent.opened);
    vm().finish();
    expect(read().stage, RecoveryStage.choosing);

    service.links.add(ResetLinkEvent.failed);
    vm().finish();
    expect(read().stage, RecoveryStage.idle);
  });
}
