import 'dart:async';

import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/models/animal_box.dart';
import 'package:faunawatch/features/fauna_lens/services/species_identification_service.dart';
import 'package:faunawatch/features/fauna_lens/viewmodels/animal_boxes_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ai_fakes.dart';

void main() {
  late FakeIdentificationService service;

  final red = sampleBox();
  final blue = sampleBox(color: AnimalBoxColor.blue, name: 'heron');
  final yellow = sampleBox(color: AnimalBoxColor.yellow, name: 'crow');
  final green = sampleBox(color: AnimalBoxColor.green, name: 'cat');

  ProviderContainer makeContainer({String? userId = 'user-a'}) {
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => Stream.value(userId)),
        speciesIdentificationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    // Keep the auto-dispose ViewModel alive for the whole test.
    container.listen(animalBoxesViewModelProvider, (_, _) {});
    return container;
  }

  setUp(() => service = FakeIdentificationService());

  test('finds the animals and chooses a single one straight away', () async {
    final container = makeContainer();
    final viewModel = container.read(animalBoxesViewModelProvider.notifier);
    expect(container.read(animalBoxesViewModelProvider).isFinding, isTrue);

    await viewModel.findAnimals('photo.jpg');

    final state = container.read(animalBoxesViewModelProvider);
    expect(service.searchedPaths, ['photo.jpg']);
    expect(state.status, AnimalBoxesStatus.ready);
    expect(state.boxes, [red]);
    expect(state.chosenBoxes, [red]);
    expect(state.canAnalyse, isTrue);
  });

  test('several animals found are left for the user to choose', () async {
    service.found = [red, blue];
    final container = makeContainer();
    await container
        .read(animalBoxesViewModelProvider.notifier)
        .findAnimals('photo.jpg');

    final state = container.read(animalBoxesViewModelProvider);
    expect(state.boxes, hasLength(2));
    expect(state.chosen, isEmpty);
    expect(state.canAnalyse, isFalse);
  });

  test('no animal found offers drawing a box', () async {
    service.found = [];
    final container = makeContainer();
    await container
        .read(animalBoxesViewModelProvider.notifier)
        .findAnimals('photo.jpg');

    final state = container.read(animalBoxesViewModelProvider);
    expect(state.foundNothing, isTrue);
    expect(state.canDrawBox, isTrue);
    expect(state.canAnalyse, isFalse);
  });

  test('up to three animals can be chosen, in photo order', () async {
    service.found = [red, blue, yellow, green];
    final container = makeContainer();
    final viewModel = container.read(animalBoxesViewModelProvider.notifier);
    await viewModel.findAnimals('photo.jpg');

    expect(viewModel.toggle(yellow), ChooseBoxOutcome.chosen);
    expect(viewModel.toggle(red), ChooseBoxOutcome.chosen);
    expect(viewModel.toggle(blue), ChooseBoxOutcome.chosen);
    expect(viewModel.toggle(green), ChooseBoxOutcome.limitReached);
    var state = container.read(animalBoxesViewModelProvider);
    expect(state.chosenBoxes.map((b) => b.color), [
      AnimalBoxColor.red,
      AnimalBoxColor.blue,
      AnimalBoxColor.yellow,
    ]);

    expect(viewModel.toggle(blue), ChooseBoxOutcome.unchosen);
    expect(viewModel.toggle(green), ChooseBoxOutcome.chosen);
    state = container.read(animalBoxesViewModelProvider);
    expect(state.chosen, {
      AnimalBoxColor.red,
      AnimalBoxColor.yellow,
      AnimalBoxColor.green,
    });
  });

  test('a drawn box gets the next colour and is chosen', () async {
    service.found = [red, blue];
    final container = makeContainer();
    final viewModel = container.read(animalBoxesViewModelProvider.notifier);
    await viewModel.findAnimals('photo.jpg');

    expect(viewModel.addDrawnBox(x1: 0.9, y1: 0.9, x2: 0.5, y2: 0.4), isTrue);

    final state = container.read(animalBoxesViewModelProvider);
    final drawn = state.boxes.last;
    expect(drawn.color, AnimalBoxColor.yellow);
    expect(drawn.drawnByUser, isTrue);
    expect(
      [drawn.left, drawn.top, drawn.right, drawn.bottom],
      [0.5, 0.4, 0.9, 0.9],
    );
    expect(state.chosenBoxes, [drawn]);
  });

  test('a tiny drawn box is refused', () async {
    final container = makeContainer();
    final viewModel = container.read(animalBoxesViewModelProvider.notifier);
    await viewModel.findAnimals('photo.jpg');

    expect(
      viewModel.addDrawnBox(x1: 0.5, y1: 0.5, x2: 0.51, y2: 0.51),
      isFalse,
    );
    expect(container.read(animalBoxesViewModelProvider).boxes, [red]);
  });

  test('a drawn box is not chosen when three already are', () async {
    service.found = [red, blue, yellow];
    final container = makeContainer();
    final viewModel = container.read(animalBoxesViewModelProvider.notifier);
    await viewModel.findAnimals('photo.jpg');
    for (final box in [red, blue, yellow]) {
      viewModel.toggle(box);
    }

    viewModel.addDrawnBox(x1: 0.1, y1: 0.1, x2: 0.4, y2: 0.4);

    final state = container.read(animalBoxesViewModelProvider);
    expect(state.boxes, hasLength(4));
    expect(state.chosen, hasLength(3));
    expect(state.isChosen(state.boxes.last), isFalse);
  });

  test('no box can be drawn once every colour is used', () async {
    service.found = [
      for (final color in AnimalBoxColor.values) sampleBox(color: color),
    ];
    final container = makeContainer();
    final viewModel = container.read(animalBoxesViewModelProvider.notifier);
    await viewModel.findAnimals('photo.jpg');

    expect(container.read(animalBoxesViewModelProvider).canDrawBox, isFalse);
    expect(viewModel.addDrawnBox(x1: 0.1, y1: 0.1, x2: 0.4, y2: 0.4), isFalse);
  });

  test('searching again keeps the boxes the user drew', () async {
    service.found = [];
    final container = makeContainer();
    final viewModel = container.read(animalBoxesViewModelProvider.notifier);
    await viewModel.findAnimals('photo.jpg');
    viewModel.addDrawnBox(x1: 0.1, y1: 0.1, x2: 0.4, y2: 0.4);

    // The AI's boxes take the colours the drawn box doesn't use.
    service.found = [sampleBox(color: AnimalBoxColor.red, name: 'dog')];
    await viewModel.findAnimals('photo.jpg');

    final state = container.read(animalBoxesViewModelProvider);
    expect(state.boxes.map((b) => b.label), ['Your box', 'dog']);
    expect(state.boxes.map((b) => b.color), [
      AnimalBoxColor.red,
      AnimalBoxColor.blue,
    ]);
    expect(state.chosen, {AnimalBoxColor.red});
  });

  test('a failure is reported, and drawing still works', () async {
    service.findFailure = IdentificationFailure.noKey;
    final container = makeContainer();
    final viewModel = container.read(animalBoxesViewModelProvider.notifier);
    await viewModel.findAnimals('photo.jpg');

    var state = container.read(animalBoxesViewModelProvider);
    expect(state.status, AnimalBoxesStatus.failed);
    expect(state.failure, IdentificationFailure.noKey);
    expect(state.canDrawBox, isTrue);

    viewModel.addDrawnBox(x1: 0.1, y1: 0.1, x2: 0.4, y2: 0.4);
    state = container.read(animalBoxesViewModelProvider);
    expect(state.canAnalyse, isTrue);
  });

  test('a signed-out user is told to sign in', () async {
    final container = makeContainer(userId: null);
    await container
        .read(animalBoxesViewModelProvider.notifier)
        .findAnimals('photo.jpg');

    expect(
      container.read(animalBoxesViewModelProvider).failure,
      IdentificationFailure.signedOut,
    );
    expect(service.searchedPaths, isEmpty);
  });

  test('nothing can be analysed while the search runs', () async {
    service.findGate = Completer<void>();
    final container = makeContainer();
    final search = container
        .read(animalBoxesViewModelProvider.notifier)
        .findAnimals('photo.jpg');
    await Future<void>.delayed(Duration.zero);

    final state = container.read(animalBoxesViewModelProvider);
    expect(state.isFinding, isTrue);
    expect(state.canAnalyse, isFalse);
    expect(state.canDrawBox, isFalse);

    service.findGate!.complete();
    await search;
  });

  group('editing boxes', () {
    Future<(ProviderContainer, AnimalBoxesViewModel)> ready(
      List<AnimalBox> found,
    ) async {
      service.found = found;
      final container = makeContainer();
      final viewModel = container.read(animalBoxesViewModelProvider.notifier);
      await viewModel.findAnimals('photo.jpg');
      return (container, viewModel);
    }

    test('a single animal found is chosen and ready to edit', () async {
      final (container, _) = await ready([red]);
      final state = container.read(animalBoxesViewModelProvider);
      expect(state.active, AnimalBoxColor.red);
      expect(state.activeBox, red);
    });

    test('several animals found start with nothing to edit', () async {
      final (container, _) = await ready([red, blue]);
      expect(container.read(animalBoxesViewModelProvider).active, isNull);
    });

    test('tapping a box on the photo chooses it, then edits, then '
        'unchooses it', () async {
      final (container, viewModel) = await ready([red, blue]);
      AnimalBoxesState state() => container.read(animalBoxesViewModelProvider);

      expect(viewModel.tapBox(red), ChooseBoxOutcome.chosen);
      expect(viewModel.tapBox(blue), ChooseBoxOutcome.chosen);
      expect(state().chosen, {AnimalBoxColor.red, AnimalBoxColor.blue});
      expect(state().active, AnimalBoxColor.blue);

      // A chosen box that is not being edited becomes the edited one.
      expect(viewModel.tapBox(red), ChooseBoxOutcome.activated);
      expect(state().chosen, {AnimalBoxColor.red, AnimalBoxColor.blue});
      expect(state().active, AnimalBoxColor.red);

      // Tapping the edited box again unchooses it.
      expect(viewModel.tapBox(red), ChooseBoxOutcome.unchosen);
      expect(state().chosen, {AnimalBoxColor.blue});
      expect(state().active, isNull);
    });

    test('the list still chooses and unchooses in one tap', () async {
      final (container, viewModel) = await ready([red, blue]);
      AnimalBoxesState state() => container.read(animalBoxesViewModelProvider);

      viewModel.toggle(red);
      viewModel.toggle(blue);
      expect(state().active, AnimalBoxColor.blue);
      expect(viewModel.toggle(red), ChooseBoxOutcome.unchosen);
      expect(state().chosen, {AnimalBoxColor.blue});
      expect(state().active, AnimalBoxColor.blue);
      expect(viewModel.toggle(blue), ChooseBoxOutcome.unchosen);
      expect(state().active, isNull);
    });

    test(
      'a fourth box tapped on the photo is refused and not edited',
      () async {
        final (container, viewModel) = await ready([red, blue, yellow, green]);
        viewModel.tapBox(red);
        viewModel.tapBox(blue);
        viewModel.tapBox(yellow);
        expect(viewModel.tapBox(green), ChooseBoxOutcome.limitReached);
        final state = container.read(animalBoxesViewModelProvider);
        expect(state.chosen.contains(AnimalBoxColor.green), isFalse);
        expect(state.active, AnimalBoxColor.yellow);
      },
    );

    test('a drawn box is ready to edit', () async {
      final (container, viewModel) = await ready([red, blue]);
      viewModel.addDrawnBox(x1: 0.5, y1: 0.5, x2: 0.9, y2: 0.9);
      expect(
        container.read(animalBoxesViewModelProvider).active,
        AnimalBoxColor.yellow,
      );
    });

    test('a resized AI box stays chosen and keeps its name', () async {
      final (container, viewModel) = await ready([red, blue]);
      viewModel.tapBox(red);

      final resized = red.resized(BoxCorner.bottomRight, 0.8, 0.9);
      expect(viewModel.updateBox(resized), isTrue);

      final state = container.read(animalBoxesViewModelProvider);
      expect(state.boxes, [resized, blue]);
      expect(state.chosenBoxes, [resized]);
      expect(state.chosenBoxes.single.name, 'turtle');
      expect(state.active, AnimalBoxColor.red);
    });

    test('an update for a missing box or a too small box is refused', () async {
      final (container, viewModel) = await ready([red]);
      expect(viewModel.updateBox(blue), isFalse);
      expect(
        viewModel.updateBox(
          const AnimalBox(
            left: 0.1,
            top: 0.1,
            right: 0.11,
            bottom: 0.5,
            color: AnimalBoxColor.red,
          ),
        ),
        isFalse,
      );
      expect(container.read(animalBoxesViewModelProvider).boxes, [red]);
    });

    test('deleting a box unchooses it and frees its colour', () async {
      final (container, viewModel) = await ready([red, blue]);
      AnimalBoxesState state() => container.read(animalBoxesViewModelProvider);
      viewModel.tapBox(red);
      viewModel.tapBox(blue);

      viewModel.deleteBox(AnimalBoxColor.red);
      expect(state().boxes, [blue]);
      expect(state().chosen, {AnimalBoxColor.blue});
      expect(state().active, AnimalBoxColor.blue);

      // The edited box can be deleted too, leaving nothing to edit.
      viewModel.deleteBox(AnimalBoxColor.blue);
      expect(state().boxes, isEmpty);
      expect(state().chosen, isEmpty);
      expect(state().active, isNull);
      expect(state().canAnalyse, isFalse);

      // The freed colour goes to the next box drawn.
      viewModel.addDrawnBox(x1: 0.1, y1: 0.1, x2: 0.4, y2: 0.4);
      expect(state().boxes.single.color, AnimalBoxColor.red);
    });

    test('deleting frees room for another drawn box', () async {
      final (container, viewModel) = await ready([
        for (final color in AnimalBoxColor.values) sampleBox(color: color),
      ]);
      AnimalBoxesState state() => container.read(animalBoxesViewModelProvider);
      expect(state().canDrawBox, isFalse);
      viewModel.deleteBox(AnimalBoxColor.purple);
      expect(state().canDrawBox, isTrue);
    });

    test('searching again keeps a drawn box being edited', () async {
      service.found = [];
      final container = makeContainer();
      final viewModel = container.read(animalBoxesViewModelProvider.notifier);
      await viewModel.findAnimals('photo.jpg');
      viewModel.addDrawnBox(x1: 0.1, y1: 0.1, x2: 0.4, y2: 0.4);

      service.found = [blue];
      await viewModel.findAnimals('photo.jpg');
      final state = container.read(animalBoxesViewModelProvider);
      expect(state.active, AnimalBoxColor.red);
      expect(state.activeBox!.drawnByUser, isTrue);
    });
  });
}
