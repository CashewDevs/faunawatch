import 'dart:async';

import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/window_security_service.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/services/species_identification_service.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_ai_result_screen.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/views/ai_key_setup_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ai_fakes.dart';

const _photo = FaunaLensPhoto(
  path: 'missing.jpg',
  source: FaunaLensPhotoSource.camera,
);

void main() {
  late FakeIdentificationService service;
  late FakeKeyStorage keys;
  AiResultChoice? choice;
  var popped = false;

  setUp(() {
    service = FakeIdentificationService();
    keys = FakeKeyStorage();
    choice = null;
    popped = false;
  });

  /// Opens the screen on top of a placeholder so its pop result is captured.
  Future<void> open(
    WidgetTester tester, {
    FaunaLensPhoto photo = _photo,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => Stream.value('user-a')),
          speciesIdentificationServiceProvider.overrideWithValue(service),
          aiApiKeyStorageServiceProvider.overrideWithValue(keys),
          windowSecurityServiceProvider.overrideWithValue(_NoWindowSecurity()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  choice = await Navigator.of(context).push<AiResultChoice>(
                    MaterialPageRoute(
                      builder: (_) => FaunaLensAiResultScreen(photo: photo),
                    ),
                  );
                  popped = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  testWidgets('shows the layout as placeholders while the AI works', (
    tester,
  ) async {
    service.gate = Completer<void>();
    await open(tester, settle: false);

    expect(find.text('AI Result'), findsOneWidget);
    expect(find.text('✦ Preliminary AI assessment'), findsOneWidget);
    expect(
      find.text('AI can be wrong. Please check the results before you post.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Identifying the animal in your photo'),
      findsOneWidget,
    );
    expect(find.text('Possible species'), findsNothing);

    // Nothing to use yet: tapping does not leave the screen.
    await tester.tap(find.text('Use these results'));
    await tester.pump();
    expect(popped, isFalse);

    service.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Possible species'), findsOneWidget);
  });

  testWidgets('shows every part of the result', (tester) async {
    await open(tester);

    expect(service.photoPaths, ['missing.jpg']);
    expect(find.text('Possible species'), findsOneWidget);
    expect(
      find.text('Up to 3 guesses. None of these is confirmed.'),
      findsOneWidget,
    );
    expect(find.text('Red-eared Slider'), findsOneWidget);
    expect(find.text('Trachemys scripta elegans'), findsOneWidget);
    expect(find.text('Malayan Box Turtle'), findsOneWidget);
    expect(find.text('Asian Leaf Turtle'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Uncertain'), findsOneWidget);
    expect(find.text('VISIBLE CONDITION'), findsOneWidget);
    expect(find.text('No injury seen in this photo.'), findsOneWidget);
    expect(find.text('SEVERITY'), findsOneWidget);
    expect(find.text('The animal looks calm.'), findsOneWidget);
    expect(find.text('What to do'), findsOneWidget);
    expect(
      find.text('Keep your distance and do not pick up the animal.'),
      findsOneWidget,
    );
    expect(find.textContaining('from Gemini'), findsOneWidget);
    expect(find.text('Possible invasive species'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('warns about a possible invasive species only when matched', (
    tester,
  ) async {
    service.result = sampleIdentification(invasive: true);
    await open(tester);

    expect(find.text('Possible invasive species'), findsOneWidget);
    expect(
      find.textContaining('not an official classification'),
      findsOneWidget,
    );
  });

  testWidgets('Use these results returns the result', (tester) async {
    await open(tester);

    await tester.tap(find.text('Use these results'));
    await tester.pumpAndSettle();

    expect(choice, isA<UseAiResults>());
    expect(
      (choice! as UseAiResults).result.topGuess!.commonName,
      'Red-eared Slider',
    );
  });

  testWidgets('Retake photo returns a retake choice', (tester) async {
    await open(tester);

    await tester.tap(find.text('Retake photo'));
    await tester.pumpAndSettle();

    expect(choice, isA<RetakeFromAiResult>());
  });

  testWidgets('a gallery photo offers choosing another one', (tester) async {
    await open(
      tester,
      photo: const FaunaLensPhoto(
        path: 'g.jpg',
        source: FaunaLensPhotoSource.gallery,
      ),
    );
    expect(find.text('Choose another photo'), findsOneWidget);
    expect(find.text('Retake photo'), findsNothing);
  });

  testWidgets('back returns without a choice', (tester) async {
    await open(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    expect(choice, isNull);
  });

  testWidgets('no animal found cannot be used for a post', (tester) async {
    service.result = sampleIdentification(noAnimal: true);
    await open(tester);

    expect(find.textContaining('No animal was found'), findsOneWidget);
    await tester.tap(find.text('Use these results'));
    await tester.pumpAndSettle();
    expect(popped, isFalse);
  });

  testWidgets('without a key, adding one retries the analysis', (tester) async {
    service.failure = IdentificationFailure.noKey;
    await open(tester);

    expect(find.text('Add an AI key first'), findsOneWidget);
    await tester.tap(find.text('Add an AI key'));
    await tester.pumpAndSettle();
    expect(find.byType(AiKeySetupView), findsOneWidget);

    service.failure = null;
    keys.keys[('user-a', AiProvider.gemini)] = 'new-key';
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(service.photoPaths, hasLength(2));
    expect(find.text('Possible species'), findsOneWidget);
  });

  testWidgets('a network failure can be retried', (tester) async {
    service.failure = IdentificationFailure.network;
    await open(tester);

    expect(find.text("Couldn't reach the AI"), findsOneWidget);
    service.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Possible species'), findsOneWidget);
  });

  testWidgets('an unreadable photo offers no retry', (tester) async {
    service.failure = IdentificationFailure.unreadablePhoto;
    await open(tester);

    expect(find.text("Couldn't read this photo"), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });
}

class _NoWindowSecurity implements WindowSecurityService {
  @override
  Future<void> enableSecure() async {}

  @override
  Future<void> disableSecure() async {}
}
