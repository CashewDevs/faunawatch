/// Profile details associated with the active authenticated session.
class AuthSessionProfile {
  const AuthSessionProfile({required this.userId, this.displayName});

  final String userId;
  final String? displayName;

  bool get hasDisplayName => displayName?.trim().isNotEmpty ?? false;
}
