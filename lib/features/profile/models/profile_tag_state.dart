import 'package:faunawatch/features/profile/models/profile_tag.dart';

class ProfileTagState {
  const ProfileTagState({this.isSaving = false, this.errorMessage});

  final bool isSaving;
  final String? errorMessage;

  List<ProfileTag> get availableTags => ProfileTag.values;

  ProfileTagState copyWith({bool? isSaving, String? errorMessage}) =>
      ProfileTagState(
        isSaving: isSaving ?? this.isSaving,
        errorMessage: errorMessage,
      );
}
