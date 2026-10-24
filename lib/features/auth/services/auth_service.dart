import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Contract for authentication operations.
abstract interface class AuthService {
  /// Signs in a user with email/username and password.
  Future<bool> login(String email, String password);

  /// Registers a new user with email and password.
  Future<bool> signUp(String email, String password);
}

/// Mock / default implementation for authentication service.
class FaunaAuthService implements AuthService {
  const FaunaAuthService();

  @override
  Future<bool> login(String email, String password) async {
    // Simulated authentication latency
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return email.trim().isNotEmpty && password.isNotEmpty;
  }

  @override
  Future<bool> signUp(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return email.trim().isNotEmpty && password.isNotEmpty;
  }
}

/// Riverpod provider exposing [AuthService].
final authServiceProvider = Provider<AuthService>((ref) {
  return const FaunaAuthService();
});
