import 'package:camera/camera.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/create_post/viewmodels/create_post_viewmodel.dart';
import 'package:faunawatch/core/services/image_picker_service.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/services/fauna_lens_camera_service.dart';
import 'package:faunawatch/features/fauna_lens/services/photo_location_service.dart';
import 'package:faunawatch/features/fauna_lens/services/species_identification_service.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_ai_result_screen.dart';
import 'package:faunawatch/features/fauna_lens/views/fauna_lens_view.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';
import 'package:faunawatch/features/shell/views/widgets/shell_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ai_fakes.dart';

const _here = GeoCoordinates(latitude: 14.6, longitude: 121.0);
const _noLocationNotice =
    'No location was found in this photo. You will set where you saw the animal when you post.';

void main() {
  late _FakeCamera camera;
  late _FakeLocations locations;
  late _FakePicker picker;
  late FakeIdentificationService identification;
  late ProviderContainer container;

  Future<void> openFromHeader(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(appBar: ShellHeader())),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Open camera'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    camera = _FakeCamera();
    locations = _FakeLocations();
    picker = _FakePicker();
    identification = FakeIdentificationService();
    container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => Stream.value('user-a')),
        speciesIdentificationServiceProvider.overrideWithValue(identification),
        faunaLensCameraServiceProvider.overrideWithValue(camera),
        photoLocationServiceProvider.overrideWithValue(locations),
        imagePickerServiceProvider.overrideWithValue(picker),
      ],
    );
    addTearDown(container.dispose);
  });

  testWidgets('header button shows a camera instead of the placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(appBar: ShellHeader())),
    );
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsNothing);
  });

  testWidgets('camera screen shows its guidance and closes', (tester) async {
    await openFromHeader(tester);
    expect(find.byType(FaunaLensView), findsOneWidget);
    expect(
      find.text(
        'Stay at a safe distance. Never approach or handle the animal to get a photo.',
      ),
      findsOneWidget,
    );
    expect(find.text('Fit the whole animal inside the frame.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel('Close camera'));
    await tester.pumpAndSettle();
    expect(find.byType(FaunaLensView), findsNothing);
    expect(camera.isOpen, isFalse);
  });

  testWidgets('flash button toggles and reports a missing flash', (
    tester,
  ) async {
    await openFromHeader(tester);
    await tester.tap(find.bySemanticsLabel('Turn flash on'));
    await tester.pump();
    expect(camera.flashOn, isTrue);
    expect(find.bySemanticsLabel('Turn flash off'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Turn flash off'));
    await tester.pump();
    expect(camera.flashOn, isFalse);

    camera.hasFlash = false;
    await tester.tap(find.bySemanticsLabel('Turn flash on'));
    await tester.pump();
    expect(find.text("This camera doesn't have a flash."), findsOneWidget);
  });

  testWidgets('switch button changes camera', (tester) async {
    await openFromHeader(tester);
    await tester.tap(find.bySemanticsLabel('Switch camera'));
    await tester.pumpAndSettle();
    expect(camera.switchCalls, 1);
  });

  testWidgets('offers a retry and the gallery when the camera will not open', (
    tester,
  ) async {
    camera.startError = CameraException('CameraAccessDenied', null);
    await openFromHeader(tester);
    expect(find.textContaining("Can't open the camera."), findsOneWidget);
    expect(tester.takeException(), isNull);

    camera.startError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Can't open the camera."), findsNothing);
    expect(camera.isOpen, isTrue);
  });

  testWidgets('shutter opens the capture review, and Retake returns', (
    tester,
  ) async {
    locations.current = _here;
    await openFromHeader(tester);
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();

    expect(find.text('Happy with this photo?'), findsOneWidget);
    expect(find.text('Location captured'), findsOneWidget);
    expect(
      find.text(
        'Ask AI to suggest what animal this might be, or retake it for a clearer shot.',
      ),
      findsOneWidget,
    );
    expect(find.text(_noLocationNotice), findsNothing);
    expect(camera.isOpen, isFalse);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Retake photo'));
    await tester.pumpAndSettle();
    expect(find.text('Happy with this photo?'), findsNothing);
    expect(find.text('Fit the whole animal inside the frame.'), findsOneWidget);
    expect(camera.isOpen, isTrue);
  });

  testWidgets('never claims a location was captured when it was not', (
    tester,
  ) async {
    await openFromHeader(tester);
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();

    expect(find.text('Location captured'), findsNothing);
    expect(find.text('No location'), findsOneWidget);
    expect(find.text(_noLocationNotice), findsOneWidget);
  });

  testWidgets('gallery photo with no location shows the notice', (
    tester,
  ) async {
    picker.paths = ['first.jpg', 'second.jpg'];
    await openFromHeader(tester);
    await tester.tap(find.bySemanticsLabel('Choose from gallery'));
    await tester.pumpAndSettle();

    expect(find.text('Use this photo?'), findsOneWidget);
    expect(find.text('From your gallery'), findsOneWidget);
    expect(find.text(_noLocationNotice), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Choose another'));
    await tester.pumpAndSettle();
    expect(picker.calls, 2);
    expect(find.text('Use this photo?'), findsOneWidget);
  });

  testWidgets('gallery photo with a location hides the notice', (tester) async {
    picker.paths = ['first.jpg'];
    locations.inPhoto = _here;
    await openFromHeader(tester);
    await tester.tap(find.bySemanticsLabel('Choose from gallery'));
    await tester.pumpAndSettle();

    expect(find.text('From your gallery'), findsOneWidget);
    expect(find.text(_noLocationNotice), findsNothing);
  });

  testWidgets('back button returns to the camera', (tester) async {
    await openFromHeader(tester);
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Back to camera'));
    await tester.pumpAndSettle();
    expect(find.text('Fit the whole animal inside the frame.'), findsOneWidget);
  });

  testWidgets('system back from the review returns to the camera', (
    tester,
  ) async {
    await openFromHeader(tester);
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(FaunaLensView), findsOneWidget);
    expect(find.text('Fit the whole animal inside the frame.'), findsOneWidget);
  });

  testWidgets('Ask AI opens the AI result for the photo', (tester) async {
    await openFromHeader(tester);
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();

    expect(find.byType(FaunaLensAiResultScreen), findsOneWidget);
    expect(identification.photoPaths, ['camera.jpg']);
    expect(find.text('Red-eared Slider'), findsOneWidget);

    // Back keeps the photo under review.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Happy with this photo?'), findsOneWidget);
  });

  testWidgets('Use these results starts a post with the top guess', (
    tester,
  ) async {
    identification.result = sampleIdentification(invasive: true);
    await openFromHeader(tester);
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use these results'));
    await tester.pumpAndSettle();

    expect(find.byType(FaunaLensView), findsNothing);
    expect(container.read(shellViewModelProvider), ShellDestination.addPost);
    final draft = container.read(createPostViewModelProvider);
    expect(draft.photoPath, 'camera.jpg');
    expect(draft.species, 'Red-eared Slider (Trachemys scripta elegans)');
    expect(draft.category, ReportCategory.possibleInvasiveSpecies);
    // Carried into the draft so it is saved to ai_analyses on submit.
    expect(draft.aiResult, same(identification.result));
  });

  testWidgets('a result without an invasive match uses the AI category', (
    tester,
  ) async {
    identification.result = sampleIdentification(
      category: ReportCategory.animalInNeed,
    );
    await openFromHeader(tester);
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use these results'));
    await tester.pumpAndSettle();

    final draft = container.read(createPostViewModelProvider);
    expect(draft.species, 'Red-eared Slider (Trachemys scripta elegans)');
    expect(draft.category, ReportCategory.animalInNeed);
  });

  testWidgets('Retake photo from the AI result reopens the camera', (
    tester,
  ) async {
    await openFromHeader(tester);
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retake photo'));
    await tester.pumpAndSettle();

    expect(find.byType(FaunaLensAiResultScreen), findsNothing);
    expect(find.text('Fit the whole animal inside the frame.'), findsOneWidget);
    expect(camera.isOpen, isTrue);
  });

  testWidgets('Skip AI closes FaunaLens and goes to Add post', (tester) async {
    await openFromHeader(tester);
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip AI'));
    await tester.pumpAndSettle();
    expect(find.byType(FaunaLensView), findsNothing);
    expect(container.read(shellViewModelProvider), ShellDestination.addPost);
    expect(container.read(createPostViewModelProvider).photoPath, 'camera.jpg');
  });

  testWidgets('review fits a short screen without overflowing', (tester) async {
    picker.paths = ['first.jpg'];
    await openFromHeader(tester);
    await tester.tap(find.bySemanticsLabel('Choose from gallery'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1800, 1080);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _FakeCamera implements FaunaLensCameraService {
  bool isOpen = false;
  bool flashOn = false;
  bool hasFlash = true;
  int switchCalls = 0;
  Object? startError;

  @override
  CameraController? get controller => null;

  @override
  Future<void> start() async {
    if (startError case final error?) throw error;
    isOpen = true;
  }

  @override
  Future<void> stop() async => isOpen = false;

  @override
  Future<bool> switchLens() async {
    switchCalls++;
    return true;
  }

  @override
  Future<void> setFlash({required bool isOn}) async {
    if (!hasFlash) throw CameraException('setFlashModeFailed', null);
    flashOn = isOn;
  }

  @override
  Future<String> takePicture() async => 'camera.jpg';
}

class _FakeLocations implements PhotoLocationService {
  GeoCoordinates? current;
  GeoCoordinates? inPhoto;

  @override
  Future<GeoCoordinates?> currentLocation() async => current;

  @override
  Future<GeoCoordinates?> locationInPhoto(String path) async => inPhoto;
}

class _FakePicker implements ImagePickerService {
  List<String> paths = const [];
  int calls = 0;

  @override
  Future<String?> pickImage() async {
    final path = calls < paths.length ? paths[calls] : null;
    calls++;
    return path;
  }
}
