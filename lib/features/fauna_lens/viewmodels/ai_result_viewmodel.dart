import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/services/species_identification_service.dart';

enum AiResultStatus { analyzing, done, failed }

/// Presentation state for the FaunaLens AI Result screen.
class AiResultState {
  const AiResultState({
    this.status = AiResultStatus.analyzing,
    this.result,
    this.failure,
    this.photoSubject = '',
  });

  final AiResultStatus status;
  final AiIdentification? result;
  final IdentificationFailure? failure;

  /// What the photo showed instead, for [IdentificationFailure.notAnimal].
  final String photoSubject;

  bool get isAnalyzing => status == AiResultStatus.analyzing;

  /// "Use these results" is only offered for a result that names an animal.
  bool get canUseResults => result?.hasSpecies ?? false;
}

/// Runs the AI identification for one photo.
class AiResultViewModel extends AutoDisposeNotifier<AiResultState> {
  // Identifies the latest request, so an older reply can't replace a newer one.
  int _request = 0;
  bool _disposed = false;

  @override
  AiResultState build() {
    ref.onDispose(() {
      _disposed = true;
      _request++;
    });
    return const AiResultState();
  }

  Future<void> analyze(String photoPath) async {
    final request = ++_request;
    state = const AiResultState();

    AiResultState next;
    try {
      final userId = await ref.read(currentUserIdProvider.future);
      if (userId == null) {
        throw const IdentificationException(IdentificationFailure.signedOut);
      }
      final result = await ref
          .read(speciesIdentificationServiceProvider)
          .identify(userId: userId, photoPath: photoPath);
      next = AiResultState(status: AiResultStatus.done, result: result);
    } on IdentificationException catch (error) {
      next = AiResultState(
        status: AiResultStatus.failed,
        failure: error.failure,
        photoSubject: error.photoSubject,
      );
    } catch (error) {
      // Only the error type is logged: never a key or provider response.
      debugPrint('AiResultViewModel: analysis failed (${error.runtimeType})');
      next = const AiResultState(
        status: AiResultStatus.failed,
        failure: IdentificationFailure.badResponse,
      );
    }
    if (_disposed || request != _request) return;
    state = next;
  }
}

final aiResultViewModelProvider =
    AutoDisposeNotifierProvider<AiResultViewModel, AiResultState>(
      AiResultViewModel.new,
    );
