import 'dart:async';

import 'package:faunawatch/features/post_management/services/post_management_service.dart';

/// Records hide, show and delete calls; [error] makes them fail.
class FakePostManagementService implements PostManagementService {
  final hiddenCalls = <(String, bool)>[];
  final deleted = <String>[];
  Object? error;

  /// While set, actions wait for it.
  Completer<void>? gate;

  @override
  Future<void> setHidden(String postId, {required bool hidden}) async {
    await gate?.future;
    if (error != null) throw error!;
    hiddenCalls.add((postId, hidden));
  }

  @override
  Future<void> delete(String postId) async {
    await gate?.future;
    if (error != null) throw error!;
    deleted.add(postId);
  }
}
