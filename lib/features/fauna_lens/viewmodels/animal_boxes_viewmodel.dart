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
    this.active,
    this.failure,
  });

  final AnimalBoxesStatus status;

  /// Every box on the photo: the AI's first, then the user's.
  final List<AnimalBox> boxes;

  /// The colours of the boxes the user chose.
  final Set<AnimalBoxColor> chosen;

  /// The colour of the box being edited: the chosen box the user last
  /// tapped or drew. It shows resize handles and a delete button. Always one
  /// of [chosen], or null.
  final AnimalBoxColor? active;

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

  /// The box being edited, or null.
  AnimalBox? get activeBox {
    for (final box in boxes) {
      if (box.color == active) return box;
    }
    return null;
  }

  bool get canAnalyse => !isFinding && chosen.isNotEmpty;

  /// Another box can be drawn while there is a colour left for it.
  bool get canDrawBox => !isFinding && boxes.length < AnimalBox.maxBoxes;

  static const _keep = Object();

  /// Pass `active: null` to clear the box being edited.
  AnimalBoxesState copyWith({
    AnimalBoxesStatus? status,
    List<AnimalBox>? boxes,
    Set<AnimalBoxColor>? chosen,
    Object? active = _keep,
  }) => AnimalBoxesState(
    status: status ?? this.status,
    boxes: boxes ?? this.boxes,
    chosen: chosen ?? this.chosen,
    active: identical(active, _keep) ? this.active : active as AnimalBoxColor?,
    failure: failure,
  );
}

/// What happened when the user tapped a box.
enum ChooseBoxOutcome {
  chosen,
  unchosen,
  limitReached,

  /// An already chosen box became the one being edited.
  activated,
}

/// Finds the animals in a FaunaLens photo and keeps track of which boxes the
/// user chose, drew, resized, moved and deleted.
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
      active: drawn.any((box) => box.color == state.active)
          ? state.active
          : null,
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

  /// Chooses or unchooses [box] in one tap (the list under the photo). A box
  /// just chosen becomes the one being edited. At most [AnimalBox.maxChosen]
  /// can be chosen.
  ChooseBoxOutcome toggle(AnimalBox box) {
    final chosen = {...state.chosen};
    if (chosen.remove(box.color)) {
      state = state.copyWith(
        chosen: chosen,
        active: state.active == box.color ? null : state.active,
      );
      return ChooseBoxOutcome.unchosen;
    }
    if (chosen.length >= AnimalBox.maxChosen) {
      return ChooseBoxOutcome.limitReached;
    }
    state = state.copyWith(chosen: chosen..add(box.color), active: box.color);
    return ChooseBoxOutcome.chosen;
  }

  /// A tap on [box] on the photo. An unchosen box is chosen (and edited). A
  /// chosen box becomes the one being edited, and tapping the box already
  /// being edited unchooses it.
  ChooseBoxOutcome tapBox(AnimalBox box) {
    if (state.isChosen(box) && state.active != box.color) {
      state = state.copyWith(active: box.color);
      return ChooseBoxOutcome.activated;
    }
    return toggle(box);
  }

  /// Replaces the box of the same colour with [box], after the user resized
  /// or moved it. It stays chosen. Returns false when no box has that colour
  /// or [box] is outside the photo or smaller than [AnimalBox.minSize].
  bool updateBox(AnimalBox box) {
    final index = state.boxes.indexWhere((b) => b.color == box.color);
    if (index < 0 || !box.isValid) return false;
    state = state.copyWith(boxes: [...state.boxes]..[index] = box);
    return true;
  }

  /// Removes the box of colour [color]. It is unchosen too, and its colour is
  /// free for a new box.
  void deleteBox(AnimalBoxColor color) {
    if (!state.boxes.any((box) => box.color == color)) return;
    state = state.copyWith(
      boxes: [
        for (final box in state.boxes)
          if (box.color != color) box,
      ],
      chosen: {...state.chosen}..remove(color),
      active: state.active == color ? null : state.active,
    );
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
    final isChosen = state.chosen.length < AnimalBox.maxChosen;
    state = state.copyWith(
      boxes: [...state.boxes, box],
      chosen: isChosen ? {...state.chosen, color} : null,
      active: isChosen ? color : state.active,
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
    var active = state.active;
    if (boxes.length == 1) {
      chosen.add(boxes.single.color);
      active = boxes.single.color;
    }
    return AnimalBoxesState(
      status: AnimalBoxesStatus.ready,
      boxes: boxes,
      chosen: chosen,
      active: active,
    );
  }

  AnimalBoxesState _failed(IdentificationFailure failure) => AnimalBoxesState(
    status: AnimalBoxesStatus.failed,
    boxes: state.boxes,
    chosen: state.chosen,
    active: state.active,
    failure: failure,
  );
}

final animalBoxesViewModelProvider =
    AutoDisposeNotifierProvider<AnimalBoxesViewModel, AnimalBoxesState>(
      AnimalBoxesViewModel.new,
    );
