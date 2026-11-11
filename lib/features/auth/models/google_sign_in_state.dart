import 'package:faunawatch/features/auth/models/auth_destination.dart';

class GoogleSignInState {
  const GoogleSignInState({this.isBusy = false, this.destination, this.error});

  final bool isBusy;
  final AuthDestination? destination;
  final String? error;
}
