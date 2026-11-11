import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/auth/models/auth_destination.dart';
import 'package:faunawatch/features/auth/models/google_sign_in_state.dart';
import 'package:faunawatch/features/auth/services/google_auth_service.dart';

class GoogleSignInViewModel extends AutoDisposeNotifier<GoogleSignInState> {
  StreamSubscription<void>? _subscription;
  Timer? _timeout;
  int _attempt = 0;
  bool _resolving = false;

  @override
  GoogleSignInState build() {
    ref.onDispose(() {
      _attempt++;
      _subscription?.cancel();
      _timeout?.cancel();
    });
    return const GoogleSignInState();
  }

  Future<void> signIn() async {
    if (state.isBusy) return;
    final attempt = ++_attempt;
    final service = ref.read(googleAuthServiceProvider);
    state = const GoogleSignInState(isBusy: true);
    _subscription = service.signedIn.listen(
      (_) => _complete(attempt),
      onError: (Object error, StackTrace stack) => _fail(attempt),
    );
    _timeout = Timer(const Duration(minutes: 3), () => _fail(attempt));
    try {
      final opened = await service.launchSignIn();
      if (!opened) _fail(attempt);
    } catch (_) {
      _fail(attempt);
    }
  }

  Future<void> _complete(int attempt) async {
    if (attempt != _attempt || _resolving) return;
    _resolving = true;
    try {
      final profile = await ref
          .read(googleAuthServiceProvider)
          .loadSessionProfile();
      if (attempt != _attempt) return;
      if (profile == null) {
        _fail(attempt);
      } else {
        _stop();
        state = GoogleSignInState(
          destination: profile.hasDisplayName
              ? AuthDestination.home
              : AuthDestination.profileSetup,
        );
      }
    } catch (_) {
      _fail(attempt);
    } finally {
      if (attempt == _attempt) _resolving = false;
    }
  }

  void _fail(int attempt) {
    if (attempt != _attempt) return;
    _stop();
    state = const GoogleSignInState(
      error: 'Google sign-in could not be completed. Please try again.',
    );
  }

  void _stop() {
    _attempt++;
    _subscription?.cancel();
    _subscription = null;
    _timeout?.cancel();
    _resolving = false;
  }

  void cancel() {
    _stop();
    state = const GoogleSignInState();
  }
}

final googleSignInViewModelProvider =
    NotifierProvider.autoDispose<GoogleSignInViewModel, GoogleSignInState>(
      GoogleSignInViewModel.new,
    );
