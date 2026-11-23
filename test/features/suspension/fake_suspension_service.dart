import 'dart:async';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/suspension/models/account_suspension.dart';
import 'package:faunawatch/features/suspension/services/suspension_service.dart';

/// A suspension service whose answer and live signal tests control.
class FakeSuspensionService implements SuspensionService {
  FakeSuspensionService({this.active});

  AccountSuspension? active;
  bool fails = false;
  int fetchCalls = 0;
  final changes = StreamController<void>.broadcast();

  /// Changes the answer and sends the live signal, like the database does.
  Future<void> change(AccountSuspension? next) async {
    active = next;
    changes.add(null);
  }

  @override
  Future<AccountSuspension?> fetchActive() async {
    fetchCalls++;
    if (fails) throw StateError('offline');
    return active;
  }

  @override
  Stream<void> watchChanges() => changes.stream;
}

/// Records sign-outs; can fail.
class FakeAuthService implements AuthService {
  FakeAuthService({this.fails = false, this.onSignOut});
  final bool fails;
  final void Function()? onSignOut;
  int signOutCalls = 0;

  @override
  Future<bool> login(String email, String password) async => true;
  @override
  Future<bool> signUp(String email, String password) async => true;
  @override
  Future<void> signOut() async {
    signOutCalls++;
    onSignOut?.call();
    if (fails) throw StateError('offline');
  }
}

AccountSuspension restrictedFor7Days({String id = 's1'}) => AccountSuspension(
  id: id,
  category: SuspensionCategory.spam,
  level: SuspensionLevel.restricted,
  message: 'Posting ads in comments',
  startedAt: DateTime(2026, 11, 23, 19, 40),
  endsAt: DateTime(2026, 11, 30, 19, 40),
);

AccountSuspension lockedUntilLifted({String id = 's2'}) => AccountSuspension(
  id: id,
  category: SuspensionCategory.harassment,
  level: SuspensionLevel.locked,
  message: 'Abusive messages to other users',
  startedAt: DateTime(2026, 11, 23, 9, 5),
);
