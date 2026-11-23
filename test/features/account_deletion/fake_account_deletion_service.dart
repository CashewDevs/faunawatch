import 'package:faunawatch/features/account_deletion/models/account_deletion.dart';
import 'package:faunawatch/features/account_deletion/services/account_deletion_service.dart';

/// The delete date the fake hands out: 1 Dec 2026, 3:40 PM.
final fakeDeleteAfter = DateTime(2026, 12, 1, 15, 40);

/// An account deletion service whose answers tests control.
class FakeAccountDeletionService implements AccountDeletionService {
  FakeAccountDeletionService({
    this.scheduled,
    this.requestFailure,
    this.cancelFailure,
    this.signOutFails = false,
    this.onSignOutEverywhere,
  });

  AccountDeletion? scheduled;
  AccountDeletionFailure? requestFailure;
  AccountDeletionFailure? cancelFailure;
  bool fetchFails = false;
  bool signOutFails;
  void Function()? onSignOutEverywhere;

  final List<String> requests = [];
  int fetchCalls = 0;
  int cancelCalls = 0;
  int signOutCalls = 0;

  @override
  Future<AccountDeletion?> fetchScheduled() async {
    fetchCalls++;
    if (fetchFails) throw StateError('offline');
    return scheduled;
  }

  @override
  Future<AccountDeletion> request(String confirmation) async {
    requests.add(confirmation);
    final failure = requestFailure;
    if (failure != null) throw AccountDeletionException(failure);
    return scheduled ??= AccountDeletion(deleteAfter: fakeDeleteAfter);
  }

  @override
  Future<bool> cancel() async {
    cancelCalls++;
    final failure = cancelFailure;
    if (failure != null) throw AccountDeletionException(failure);
    final hadOne = scheduled != null;
    scheduled = null;
    return hadOne;
  }

  @override
  Future<void> signOutEverywhere() async {
    signOutCalls++;
    onSignOutEverywhere?.call();
    if (signOutFails) throw StateError('offline');
  }
}
