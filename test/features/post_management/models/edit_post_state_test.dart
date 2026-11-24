import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/post_management/models/edit_post_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fauna_lens/ai_fakes.dart';
import '../fake_edit_post_service.dart';

void main() {
  EditPostState opened() {
    final post = samplePost();
    return EditPostState(
      original: post,
      description: post.description,
      photos: post.photos,
    );
  }

  test('nothing changed: nothing to save', () {
    final state = opened();
    expect(state.hasChanges, isFalse);
    expect(state.canSave, isFalse);
    expect(state.category, ReportCategory.animalInNeed);
  });

  test('a caption change keeps the photos and needs no AI', () {
    final state = opened().copyWith(description: 'New caption');
    expect(state.captionChanged, isTrue);
    expect(state.photosChanged, isFalse);
    expect(state.sendsForReview, isFalse);
    expect(state.needsAnalysis, isFalse);
    expect(state.canSave, isTrue);
    // Only spaces around it is not a change.
    expect(
      opened().copyWith(description: '  Old caption ').hasChanges,
      isFalse,
    );
  });

  test('removing the second photo keeps the cover: no AI needed', () {
    final state = opened().copyWith(photos: const [coverPhoto]);
    expect(state.photosChanged, isTrue);
    expect(state.coverChanged, isFalse);
    expect(state.needsAnalysis, isFalse);
    expect(state.sendsForReview, isTrue);
    expect(state.canSave, isTrue);
  });

  test('a new cover needs an analysis of that very photo', () {
    final state = opened().copyWith(
      photos: const [NewPhoto('/new.jpg'), coverPhoto],
    );
    expect(state.coverChanged, isTrue);
    expect(state.needsAnalysis, isTrue);
    expect(state.canSave, isFalse);

    final analysed = state.copyWith(
      analysis: sampleIdentification(
        category: ReportCategory.potentiallyDangerousAnimal,
      ),
      analysisFor: const NewPhoto('/new.jpg').key,
    );
    expect(analysed.needsAnalysis, isFalse);
    expect(analysed.canSave, isTrue);
    // The category follows the new analysis.
    expect(analysed.category, ReportCategory.potentiallyDangerousAnimal);

    // Another photo made the cover: that analysis no longer counts.
    final moved = analysed.copyWith(
      photos: const [coverPhoto, NewPhoto('/new.jpg')],
    );
    expect(moved.coverAnalysis, isNull);
    expect(moved.category, ReportCategory.animalInNeed);
  });

  test('an existing photo made the cover needs an analysis too', () {
    final state = opened().copyWith(photos: const [secondPhoto, coverPhoto]);
    expect(state.coverChanged, isTrue);
    expect(state.needsAnalysis, isTrue);
  });

  test('a post needs at least one photo, and holds three at most', () {
    final empty = opened().copyWith(photos: const []);
    expect(empty.canSave, isFalse);
    expect(empty.needsAnalysis, isFalse);
    expect(opened().freePhotoSlots, 1);
  });

  test('busy, saving or saved: no second save', () {
    final changed = opened().copyWith(description: 'x');
    expect(changed.copyWith(isBusy: true).canSave, isFalse);
    expect(changed.copyWith(isSaving: true).canSave, isFalse);
    expect(changed.copyWith(outcome: EditPostOutcome.saved).canSave, isFalse);
  });
}
