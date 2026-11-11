import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/image_picker_service.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/create_post/services/create_post_service.dart';
import 'package:faunawatch/features/create_post/viewmodels/create_post_viewmodel.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/services/photo_location_service.dart';

import '../fauna_lens/ai_fakes.dart';

class FakeCreatePostService implements CreatePostService {
  final drafts = <PostDraft>[];
  Completer<String>? pending;
  Object? error;
  @override
  Future<String> submit(PostDraft draft) async {
    drafts.add(draft);
    if (error != null) throw error!;
    return pending == null ? 'report-1' : await pending!.future;
  }
}

class FakeLocations implements PhotoLocationService {
  GeoCoordinates? location;
  @override
  Future<GeoCoordinates?> currentLocation() async => location;
  @override
  Future<GeoCoordinates?> locationInPhoto(String path) async => location;
}

class FakePicker implements ImagePickerService {
  String? path;
  @override
  Future<String?> pickImage() async => path;
}

void main() {
  late ProviderContainer container;
  late FakeCreatePostService service;
  late FakeLocations locations;
  late FakePicker picker;
  setUp(() {
    service = FakeCreatePostService();
    locations = FakeLocations();
    picker = FakePicker();
    container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => const Stream.empty()),
        createPostServiceProvider.overrideWithValue(service),
        photoLocationServiceProvider.overrideWithValue(locations),
        imagePickerServiceProvider.overrideWithValue(picker),
      ],
    );
  });
  tearDown(() => container.dispose());

  test(
    'requires category and finite in-range location before any service call',
    () async {
      final vm = container.read(createPostViewModelProvider.notifier);
      expect(await vm.submit(), isFalse);
      vm.edit(category: ReportCategory.animalInNeed);
      for (final (lat, lng) in [
        ('', ''),
        ('NaN', '1'),
        ('91', '1'),
        ('1', '181'),
        ('Infinity', '1'),
      ]) {
        vm.edit(latitude: lat, longitude: lng);
        expect(container.read(createPostViewModelProvider).canSubmit, isFalse);
        expect(await vm.submit(), isFalse);
      }
      expect(service.drafts, isEmpty);
      vm.edit(latitude: '0', longitude: '0');
      expect(await vm.submit(), isTrue);
      expect(service.drafts.single.latitude, 0);
    },
  );

  test(
    'preserves draft on failure, hides raw errors, and permits retry',
    () async {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.edit(
        category: ReportCategory.otherWildlifeIncident,
        latitude: '10.3',
        longitude: '123.9',
        description: 'Bird',
      );
      service.error = StateError('private backend details');
      expect(await vm.submit(), isFalse);
      expect(container.read(createPostViewModelProvider).description, 'Bird');
      expect(
        container.read(createPostViewModelProvider).error,
        isNot(contains('private')),
      );
      service.error = null;
      expect(await vm.submit(), isTrue);
      expect(
        container.read(createPostViewModelProvider).submittedId,
        'report-1',
      );
      expect(await vm.submit(), isFalse);
      vm.reset();
      expect(container.read(createPostViewModelProvider).category, isNull);
    },
  );

  test('ignores duplicate submissions and edits while submitting', () async {
    final vm = container.read(createPostViewModelProvider.notifier);
    vm.edit(
      category: ReportCategory.animalInNeed,
      latitude: '-90',
      longitude: '180',
    );
    service.pending = Completer();
    final submission = vm.submit();
    vm.edit(latitude: '40');
    expect(await vm.submit(), isFalse);
    expect(service.drafts, hasLength(1));
    expect(container.read(createPostViewModelProvider).latitude, '-90');
    service.pending!.complete('saved');
    expect(await submission, isTrue);
  });

  test(
    'FaunaLens handoff, GPS, and manual correction keep required location',
    () async {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.usePhoto(
        const FaunaLensPhoto(
          path: 'bird.jpg',
          source: FaunaLensPhotoSource.camera,
          coordinates: GeoCoordinates(latitude: 10.3, longitude: 123.9),
        ),
      );
      expect(container.read(createPostViewModelProvider).latitude, '10.3');
      vm.edit(longitude: '124');
      expect(container.read(createPostViewModelProvider).longitude, '124');
      await vm.locate();
      expect(
        container.read(createPostViewModelProvider).error,
        contains('Enable location'),
      );
      expect(container.read(createPostViewModelProvider).longitude, '124');
      locations.location = const GeoCoordinates(latitude: 11, longitude: 125);
      await vm.locate();
      expect(container.read(createPostViewModelProvider).latitude, '11.0');
      vm.usePhoto(
        const FaunaLensPhoto(
          path: 'other.jpg',
          source: FaunaLensPhotoSource.gallery,
        ),
      );
      expect(container.read(createPostViewModelProvider).hasLocation, isFalse);
    },
  );

  group('FaunaLens analysis', () {
    const photo = FaunaLensPhoto(
      path: 'bird.jpg',
      source: FaunaLensPhotoSource.camera,
      coordinates: GeoCoordinates(latitude: 10.3, longitude: 123.9),
    );

    test('is submitted with the photo it describes', () async {
      final vm = container.read(createPostViewModelProvider.notifier);
      final result = sampleIdentification();
      vm.usePhoto(photo, aiResult: result);
      vm.edit(description: 'Turtle');
      expect(container.read(createPostViewModelProvider).aiResult, result);
      expect(await vm.submit(), isTrue);
      expect(service.drafts.single.aiResult, same(result));
      expect(service.drafts.single.photoPath, 'bird.jpg');
    });

    test('is dropped when the photo is removed', () async {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.usePhoto(photo, aiResult: sampleIdentification());
      vm.removePhoto();
      expect(container.read(createPostViewModelProvider).aiResult, isNull);
    });

    test('is dropped when another photo is picked', () async {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.usePhoto(photo, aiResult: sampleIdentification());
      picker.path = 'other.jpg';
      await vm.pickPhoto();
      final state = container.read(createPostViewModelProvider);
      expect(state.photoPath, 'other.jpg');
      expect(state.aiResult, isNull);
    });

    test('is kept when a picker is cancelled', () async {
      final vm = container.read(createPostViewModelProvider.notifier);
      final result = sampleIdentification();
      vm.usePhoto(photo, aiResult: result);
      await vm.pickPhoto();
      expect(container.read(createPostViewModelProvider).aiResult, result);
    });

    test('is dropped when FaunaLens hands over a photo without one', () {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.usePhoto(photo, aiResult: sampleIdentification());
      vm.usePhoto(photo);
      expect(container.read(createPostViewModelProvider).aiResult, isNull);
    });

    test('is dropped when FaunaLens hands over a different photo', () {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.usePhoto(photo, aiResult: sampleIdentification());
      vm.usePhoto(
        const FaunaLensPhoto(
          path: 'other.jpg',
          source: FaunaLensPhotoSource.gallery,
        ),
      );
      final state = container.read(createPostViewModelProvider);
      expect(state.photoPath, 'other.jpg');
      expect(state.aiResult, isNull);
    });

    test('is dropped when a picked photo has GPS too', () async {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.usePhoto(photo, aiResult: sampleIdentification());
      picker.path = 'other.jpg';
      locations.location = const GeoCoordinates(latitude: 1, longitude: 2);
      await vm.pickPhoto();
      expect(container.read(createPostViewModelProvider).aiResult, isNull);
    });

    test('is dropped by reset', () {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.usePhoto(photo, aiResult: sampleIdentification());
      vm.reset();
      expect(container.read(createPostViewModelProvider).aiResult, isNull);
    });

    test('removeAiResult detaches it and keeps the rest of the form', () {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.usePhoto(
        photo,
        aiResult: sampleIdentification(category: ReportCategory.animalInNeed),
      );
      vm.edit(species: 'Red-eared Slider');
      vm.removeAiResult();
      final state = container.read(createPostViewModelProvider);
      expect(state.aiResult, isNull);
      expect(state.photoPath, 'bird.jpg');
      expect(state.category, ReportCategory.animalInNeed);
      expect(state.species, 'Red-eared Slider');
      expect(state.latitude, '10.3');
    });

    test('a post submitted after removeAiResult carries no analysis', () async {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.usePhoto(photo, aiResult: sampleIdentification());
      vm.removeAiResult();
      vm.edit(category: ReportCategory.animalInNeed);
      expect(await vm.submit(), isTrue);
      expect(service.drafts.single.aiResult, isNull);
      expect(service.drafts.single.photoPath, 'bird.jpg');
      expect(service.drafts.single.category, ReportCategory.animalInNeed);
    });

    test('usePhoto sets the category from the AI result', () {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.edit(category: ReportCategory.animalInNeed);
      vm.usePhoto(
        photo,
        aiResult: sampleIdentification(
          category: ReportCategory.potentiallyDangerousAnimal,
        ),
      );
      expect(
        container.read(createPostViewModelProvider).category,
        ReportCategory.potentiallyDangerousAnimal,
      );
      vm.usePhoto(photo, aiResult: sampleIdentification(invasive: true));
      expect(
        container.read(createPostViewModelProvider).category,
        ReportCategory.possibleInvasiveSpecies,
      );
    });

    test('usePhoto without a result keeps the chosen category', () {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.edit(category: ReportCategory.animalInNeed);
      vm.usePhoto(photo);
      expect(
        container.read(createPostViewModelProvider).category,
        ReportCategory.animalInNeed,
      );
    });

    test('edit ignores the category while attached, other fields work', () {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.usePhoto(
        photo,
        aiResult: sampleIdentification(category: ReportCategory.animalInNeed),
      );
      vm.edit(category: ReportCategory.otherWildlifeIncident, notes: 'Near');
      final state = container.read(createPostViewModelProvider);
      expect(state.category, ReportCategory.animalInNeed);
      expect(state.notes, 'Near');
    });

    test('the category is editable again after removeAiResult', () {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.usePhoto(
        photo,
        aiResult: sampleIdentification(category: ReportCategory.animalInNeed),
      );
      vm.removeAiResult();
      expect(
        container.read(createPostViewModelProvider).category,
        ReportCategory.animalInNeed,
      );
      vm.edit(category: ReportCategory.otherWildlifeIncident);
      expect(
        container.read(createPostViewModelProvider).category,
        ReportCategory.otherWildlifeIncident,
      );
    });

    test('the submitted draft carries the AI category', () async {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.usePhoto(
        photo,
        aiResult: sampleIdentification(
          category: ReportCategory.potentiallyDangerousAnimal,
        ),
      );
      expect(await vm.submit(), isTrue);
      expect(
        service.drafts.single.category,
        ReportCategory.potentiallyDangerousAnimal,
      );
    });

    test(
      'a photo picked over an analysis leaves the category editable',
      () async {
        final vm = container.read(createPostViewModelProvider.notifier);
        vm.usePhoto(photo, aiResult: sampleIdentification());
        picker.path = 'other.jpg';
        await vm.pickPhoto();
        vm.edit(category: ReportCategory.animalInNeed);
        expect(
          container.read(createPostViewModelProvider).category,
          ReportCategory.animalInNeed,
        );
      },
    );

    test('removeAiResult is ignored while busy', () async {
      final vm = container.read(createPostViewModelProvider.notifier);
      final result = sampleIdentification();
      vm.usePhoto(photo, aiResult: result);
      service.pending = Completer();
      final submission = vm.submit();
      vm.removeAiResult();
      expect(container.read(createPostViewModelProvider).aiResult, result);
      service.pending!.complete('saved');
      expect(await submission, isTrue);
    });
  });

  test(
    'picker cancellation preserves draft and gallery GPS prefills coordinates',
    () async {
      final vm = container.read(createPostViewModelProvider.notifier);
      vm.edit(description: 'Bird');
      await vm.pickPhoto();
      expect(container.read(createPostViewModelProvider).description, 'Bird');
      picker.path = 'selected.jpg';
      locations.location = const GeoCoordinates(latitude: 1, longitude: 2);
      await vm.pickPhoto();
      expect(
        container.read(createPostViewModelProvider).photoPath,
        'selected.jpg',
      );
      expect(container.read(createPostViewModelProvider).hasLocation, isTrue);
    },
  );

  test(
    'schema mapping trims optional fields and uses pending moderation without AI',
    () {
      final row = const PostDraft(
        category: ReportCategory.animalInNeed,
        latitude: 10,
        longitude: 123,
        description: '  Bird  ',
      ).toRow('user');
      expect(row['description'], 'Bird');
      expect(row['user_species'], isNull);
      expect(row['status'], 'pending');
      expect(row['ai_status'], 'unavailable');
      expect(
        () => PostDraft(
          category: ReportCategory.animalInNeed,
          latitude: double.nan,
          longitude: 1,
        ).toRow('user'),
        throwsArgumentError,
      );
    },
  );
}
