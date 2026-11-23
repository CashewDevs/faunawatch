import 'dart:async';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/password_reset/services/password_reset_service.dart';

class FakePasswordResetService implements PasswordResetService {
  final links = StreamController<ResetLinkEvent>.broadcast(sync: true);

  final sentTo = <String>[];
  final savedPasswords = <String>[];
  Object? sendError;
  Object? saveError;
  String? email = 'spotter@example.com';

  /// When set, [setNewPassword] waits for it.
  Completer<void>? pendingSave;

  @override
  Future<void> sendResetEmail(String email) async {
    if (sendError != null) throw sendError!;
    sentTo.add(email);
  }

  @override
  Stream<ResetLinkEvent> get linkEvents => links.stream;

  @override
  String? get currentEmail => email;

  @override
  Future<void> setNewPassword(String password) async {
    if (pendingSave != null) await pendingSave!.future;
    if (saveError != null) throw saveError!;
    savedPasswords.add(password);
  }

  Future<void> dispose() => links.close();
}

class FakeAuthService implements AuthService {
  int signOuts = 0;
  Object? signOutError;

  @override
  Future<bool> login(String email, String password) async => true;

  @override
  Future<bool> signUp(String email, String password) async => true;

  @override
  Future<void> signOut() async {
    if (signOutError != null) throw signOutError!;
    signOuts++;
  }
}
