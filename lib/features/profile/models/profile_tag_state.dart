import 'package:faunawatch/features/profile/models/profile_tag.dart';

class ProfileTagState {
  const ProfileTagState({
    this.activity,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final ProfileTagActivity? activity;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  ProfileTagState copyWith({bool? isSaving, String? errorMessage}) =>
      ProfileTagState(
        activity: activity,
        isLoading: isLoading,
        isSaving: isSaving ?? this.isSaving,
        errorMessage: errorMessage,
      );
}
