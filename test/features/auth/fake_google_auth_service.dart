import 'dart:async';
import 'package:faunawatch/features/auth/models/auth_destination.dart';
import 'package:faunawatch/features/auth/models/auth_session_profile.dart';
import 'package:faunawatch/features/auth/services/google_auth_service.dart';

class FakeGoogleAuthService implements GoogleAuthService {
  final events = StreamController<void>.broadcast(sync: true);
  bool opens = true;
  Object? launchError;
  Object? resolveError;
  int launches = 0;
  AuthDestination destination = AuthDestination.signedOut;
  Completer<AuthDestination>? pendingResolution;

  @override
  Stream<void> get signedIn => events.stream;

  @override
  Future<bool> launchSignIn() async {
    launches++;
    if (launchError != null) throw launchError!;
    return opens;
  }

  @override
  Future<AuthSessionProfile?> loadSessionProfile() async {
    if (resolveError != null) throw resolveError!;
    final target = pendingResolution == null
        ? destination
        : await pendingResolution!.future;
    return target == AuthDestination.signedOut
        ? null
        : AuthSessionProfile(
            userId: 'user-123',
            displayName: target == AuthDestination.home ? 'Ranger' : null,
          );
  }

  Future<void> dispose() => events.close();
}
