import 'package:flutter/material.dart';
import 'package:faunawatch/features/public_profile/views/screens/public_profile_screen.dart';

Future<void> openPublicProfile(BuildContext context, String userId) async {
  if (userId.trim().isEmpty) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: userId)),
  );
}
