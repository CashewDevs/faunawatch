import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/models/animal_box.dart';
import 'package:faunawatch/features/fauna_lens/services/species_identification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AnimalBoxesStatus { finding, ready, failed }

/// Presentation state for the "Choose animals" screen.
class AnimalBoxesState {
  const AnimalBoxesState({
    this.status = AnimalBoxesStatus.finding,
    this.boxes = const [],
    this.chosen = const {},
    this.failure,
  });

  final AnimalBoxesStatus status;

  /// Every box on the photo: the AI's first, then the user's.
  final List<AnimalBox> boxes;

  /// The colours of the boxes the user chose.
  final Set<AnimalBoxColor> chosen;

  /// Why finding the animals failed, when [status] is failed.
  final IdentificationFailure? failure;

  bool get isFinding => status == AnimalBoxesStatus.finding;

  /// The AI looked and saw no animal, and the user has drawn no box yet.
  bool get foundNothing => status == AnimalBoxesStatus.ready && boxes.isEmpty;

  /// The chosen boxes, in the order they appear on the photo's list.
  List<AnimalBox> get chosenBoxes => [
    for (final box in boxes)
      if (chosen.contains(box.color)) box,
  ];

  bool isChosen(AnimalBox box) => chosen.contains(box.color);

  bool get canAnalyse => !isFinding && chosen.isNotEmpty;

  /// Another box can be drawn while there is a colour left for it.
  bool get canDrawBox => !isFinding && boxes.length < AnimalBox.maxBoxes;

  AnimalBoxesState copyWith({
    AnimalBoxesStatus? status,
    List<AnimalBox>? boxes,
    Set<AnimalBoxColor>? chosen,
  }) => AnimalBoxesState(
    status: status ?? this.status,
    boxes: boxes ?? this.boxes,
    chosen: chosen ?? this.chosen,
    failure: failure,
  );
}

/// What happened when the user tapped a box.
enum ChooseBoxOutcome { chosen, unchosen, limitReached }

/// Finds the animals in a FaunaLens photo and keeps track of which boxes the
/// user chose and drew.
class AnimalBoxesViewModel extends AutoDisposeNotifier<AnimalBoxesState> {
  // Identifies the latest search, so an older reply can't replace a newer one.
  int _request = 0;
  bool _disposed = false;

  @override
  AnimalBoxesState build() {
    ref.onDispose(() {
      _disposed = true;
      _request++;
    });
    return const AnimalBoxesState();
  }

  /// Asks the AI where the animals in the photo are. Boxes the user drew
  /// stay. A single animal found is chosen straight away.
  Future<void> findAnimals(String photoPath) async {
    final request = ++_request;
    final drawn = [
      for (final box in state.boxes)
        if (box.drawnByUser) box,
    ];
    state = AnimalBoxesState(
      boxes: drawn,
      chosen: {for (final box in drawn) box.color},
    );

    AnimalBoxesState next;
    try {
      final userId = await ref.read(currentUserIdProvider.future);
      if (userId == null) {
        throw const IdentificationException(IdentificationFailure.signedOut);
      }
      final found = await ref
          .read(speciesIdentificationServiceProvider)
          .findAnimals(userId: userId, photoPath: photoPath);
      next = _withFound(found);
    } on IdentificationException catch (error) {
      next = _failed(error.failure);
    } catch (error) {
      // Only the error type is logged: never a key or provider response.
      debugPrint('AnimalBoxesViewModel: search failed (${error.runtimeType})');
      next = _failed(IdentificationFailure.badResponse);
    }
    if (_disposed || request != _request) return;
    state = next;
  }

  /// Chooses or unchooses [box]. At most [AnimalBox.maxChosen] can be chosen.
  ChooseBoxOutcome toggle(AnimalBox box) {
    final chosen = {...state.chosen};
    if (chosen.remove(box.color)) {
      state = state.copyWith(chosen: chosen);
      return ChooseBoxOutcome.unchosen;
    }
    if (chosen.length >= AnimalBox.maxChosen) {
      return ChooseBoxOutcome.limitReached;
    }
    state = state.copyWith(chosen: chosen..add(box.color));
    return ChooseBoxOutcome.chosen;
  }

  /// Adds a box the user drew between two corners, given as fractions of the
  /// photo. It is chosen too while fewer than [AnimalBox.maxChosen] are.
  /// Returns false when it was too small or no colour is left.
  bool addDrawnBox({
    required double x1,
    required double y1,
    required double x2,
    required double y2,
  }) {
    if (!state.canDrawBox) return false;
    final color = AnimalBox.nextColor(state.boxes);
    if (color == null) return false;
    final box = AnimalBox.fromCorners(
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      color: color,
      drawnByUser: true,
    );
    if (box == null) return false;
    state = state.copyWith(
      boxes: [...state.boxes, box],
      chosen: state.chosen.length < AnimalBox.maxChosen
          ? {...state.chosen, color}
          : null,
    );
    return true;
  }

  /// The AI's boxes come after the user's, in colours the user's don't use.
  AnimalBoxesState _withFound(List<AnimalBox> found) {
    final boxes = [...state.boxes];
    for (final box in found) {
      final color = AnimalBox.nextColor(boxes);
      if (color == null) break;
      boxes.add(
        AnimalBox(
          left: box.left,
          top: box.top,
          right: box.right,
          bottom: box.bottom,
          color: color,
          name: box.name,
        ),
      );
    }
    final chosen = {...state.chosen};
    if (boxes.length == 1) chosen.add(boxes.single.color);
    return AnimalBoxesState(
      status: AnimalBoxesStatus.ready,
      boxes: boxes,
      chosen: chosen,
    );
  }

  AnimalBoxesState _failed(IdentificationFailure failure) => AnimalBoxesState(
    status: AnimalBoxesStatus.failed,
    boxes: state.boxes,
    chosen: state.chosen,
    failure: failure,
  );
}

final animalBoxesViewModelProvider =
    AutoDisposeNotifierProvider<AnimalBoxesViewModel, AnimalBoxesState>(
      AnimalBoxesViewModel.new,
    );
