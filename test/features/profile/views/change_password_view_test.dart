import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/profile/services/password_service.dart';
import 'package:faunawatch/features/profile/views/change_password_view.dart';

class _FakePasswordService implements PasswordService {
  String? savedCurrent;
  String? savedNew;
  int resetCalls = 0;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    savedCurrent = currentPassword;
    savedNew = newPassword;
  }

  @override
  Future<String> sendPasswordResetEmail() async {
    resetCalls++;
    return 'spotter@example.com';
  }
}

void main() {
  Widget buildTestApp(_FakePasswordService service) {
    return ProviderScope(
      overrides: [passwordServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChangePasswordView(),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  group('ChangePasswordView', () {
    testWidgets(
      'renders fields, live checklist, #FECE01/#1A5DC9 button, and submits',
      (tester) async {
        final service = _FakePasswordService();
        await tester.pumpWidget(buildTestApp(service));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Change Password'), findsOneWidget);
        expect(find.text('Current password'), findsOneWidget);
        expect(find.text('Forgot your password?'), findsOneWidget);
        expect(find.text('New password'), findsOneWidget);
        expect(find.text('Confirm new password'), findsOneWidget);
        expect(find.text('Type it again'), findsOneWidget);
        expect(find.text('Your password needs'), findsOneWidget);
        expect(find.text('At least 8 characters'), findsOneWidget);
        expect(find.text('A letter and a number'), findsOneWidget);
        expect(find.text('Matches the confirmation'), findsOneWidget);
        expect(find.text('Update password'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        // Verify Update password button colors (#FECE01 bg and #1A5DC9 text).
        final button = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('update_password_button')),
        );
        expect(
          button.style?.backgroundColor?.resolve({}),
          const Color(0xFFFECE01),
        );
        final label = tester.widget<Text>(find.text('Update password'));
        expect(label.style?.color, const Color(0xFF1A5DC9));

        // Requirements update live as user types.
        await tester.enterText(
          find.byKey(const ValueKey('current_password_field')),
          'OldPass1',
        );
        await tester.enterText(
          find.byKey(const ValueKey('new_password_field')),
          'Fauna2026',
        );
        await tester.pump();
        expect(
          find.bySemanticsLabel('At least 8 characters: met'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('A letter and a number: met'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Matches the confirmation: not met'),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const ValueKey('confirm_password_field')),
          'Fauna2026',
        );
        await tester.pump();
        expect(
          find.bySemanticsLabel('Matches the confirmation: met'),
          findsOneWidget,
        );

        await tester.ensureVisible(find.text('Update password'));
        await tester.tap(find.text('Update password'));
        await tester.pumpAndSettle();

        expect(service.savedCurrent, 'OldPass1');
        expect(service.savedNew, 'Fauna2026');
        expect(find.byType(ChangePasswordView), findsNothing);
      },
    );

    testWidgets('Forgot your password sends reset link and Cancel pops', (
      tester,
    ) async {
      final service = _FakePasswordService();
      await tester.pumpWidget(buildTestApp(service));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forgot your password?'));
      await tester.pumpAndSettle();
      expect(service.resetCalls, 1);
      expect(
        find.text('Password reset link sent to spotter@example.com.'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordView), findsNothing);
    });
  });
}
