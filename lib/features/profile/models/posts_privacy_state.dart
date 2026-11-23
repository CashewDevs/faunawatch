/// The Settings › Privacy › "Private posts" switch: whether the signed-in
/// user's posts are hidden from visitors to their profile.
class PostsPrivacyState {
  const PostsPrivacyState({
    this.isPrivate = false,
    this.isLoading = false,
    this.isSaving = false,
    this.loadFailed = false,
    this.message,
  });

  final bool isPrivate;

  /// Reading the saved setting for the first time.
  final bool isLoading;

  /// A change is being saved; the switch waits until it finishes.
  final bool isSaving;

  /// The saved setting couldn't be read, so the switch can't be trusted.
  final bool loadFailed;

  /// A one-time note for the user, e.g. why a change wasn't saved.
  final String? message;

  bool get canChange => !isLoading && !isSaving && !loadFailed;

  PostsPrivacyState copyWith({
    bool? isPrivate,
    bool? isLoading,
    bool? isSaving,
    bool? loadFailed,
    String? message,
    bool clearMessage = false,
  }) => PostsPrivacyState(
    isPrivate: isPrivate ?? this.isPrivate,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    loadFailed: loadFailed ?? this.loadFailed,
    message: clearMessage ? null : message ?? this.message,
  );
}
