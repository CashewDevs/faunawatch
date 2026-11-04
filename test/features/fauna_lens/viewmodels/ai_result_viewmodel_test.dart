import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/services/species_identification_service.dart';
import 'package:faunawatch/features/fauna_lens/viewmodels/ai_result_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ai_fakes.dart';

void main() {
  late FakeIdentificationService service;

  ProviderContainer makeContainer({String? userId = 'user-a'}) {
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => Stream.value(userId)),
        speciesIdentificationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    // Keep the auto-dispose ViewModel alive for the whole test.
    container.listen(aiResultViewModelProvider, (_, _) {});
    return container;
  }

  setUp(() => service = FakeIdentificationService());

  test('starts analyzing and ends with the result', () async {
    final container = makeContainer();
    final viewModel = container.read(aiResultViewModelProvider.notifier);
    expect(container.read(aiResultViewModelProvider).isAnalyzing, isTrue);

    await viewModel.analyze('photo.jpg');

    final state = container.read(aiResultViewModelProvider);
    expect(state.status, AiResultStatus.done);
    expect(state.result!.topGuess!.commonName, 'Red-eared Slider');
    expect(state.canUseResults, isTrue);
    expect(service.photoPaths, ['photo.jpg']);
  });

  test('a result without an animal cannot be used for a post', () async {
    service.result = sampleIdentification(noAnimal: true);
    final container = makeContainer();

    await container.read(aiResultViewModelProvider.notifier).analyze('p.jpg');

    final state = container.read(aiResultViewModelProvider);
    expect(state.status, AiResultStatus.done);
    expect(state.canUseResults, isFalse);
  });

  test('reports the failure from the service', () async {
    service.failure = IdentificationFailure.noKey;
    final container = makeContainer();

    await container.read(aiResultViewModelProvider.notifier).analyze('p.jpg');

    final state = container.read(aiResultViewModelProvider);
    expect(state.status, AiResultStatus.failed);
    expect(state.failure, IdentificationFailure.noKey);
    expect(state.canUseResults, isFalse);
  });

  test('a signed-out user is told to sign in', () async {
    final container = makeContainer(userId: null);

    await container.read(aiResultViewModelProvider.notifier).analyze('p.jpg');

    expect(
      container.read(aiResultViewModelProvider).failure,
      IdentificationFailure.signedOut,
    );
    expect(service.photoPaths, isEmpty);
  });

  test('retrying clears the old failure while it works', () async {
    service.failure = IdentificationFailure.network;
    final container = makeContainer();
    final viewModel = container.read(aiResultViewModelProvider.notifier);
    await viewModel.analyze('p.jpg');

    service.failure = null;
    final retry = viewModel.analyze('p.jpg');
    expect(container.read(aiResultViewModelProvider).isAnalyzing, isTrue);
    expect(container.read(aiResultViewModelProvider).failure, isNull);
    await retry;

    expect(
      container.read(aiResultViewModelProvider).status,
      AiResultStatus.done,
    );
  });
}
