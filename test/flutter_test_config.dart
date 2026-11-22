import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Runs around every test file.
///
/// DM Sans ships with the app (assets/google_fonts/), so widget tests load it
/// from the bundle like the app does. Loading every bundled style once before
/// the file's tests keeps a font from arriving halfway through a test, which
/// would change text sizes between layout and paint.
///
/// Files without widget tests are left alone: starting the widget test
/// binding for them would replace real HTTP with a mock, which the service
/// tests that run a local server rely on.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUpAll(() async {
    if (!_hasWidgetBinding()) return;
    for (final weight in const [400, 500, 600, 700, 800, 900]) {
      GoogleFonts.dmSans(fontWeight: FontWeight.values[weight ~/ 100 - 1]);
    }
    for (final weight in const [400, 500, 600]) {
      GoogleFonts.dmSans(
        fontWeight: FontWeight.values[weight ~/ 100 - 1],
        fontStyle: FontStyle.italic,
      );
    }
    await GoogleFonts.pendingFonts();
  });
  await testMain();
}

/// Whether the file declared widget tests (which start the binding).
bool _hasWidgetBinding() {
  try {
    WidgetsBinding.instance;
    return true;
  } catch (_) {
    return false;
  }
}
