import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/suspension/models/account_suspension.dart';
import 'package:faunawatch/features/suspension/services/suspension_service.dart';
import 'package:faunawatch/features/suspension/views/suspension_gate.dart';
import 'package:faunawatch/features/suspension/views/widgets/suspension_notices.dart';
import '../fake_suspension_service.dart';

/// Like the app: the gate wraps the navigator, whose home has a banner and
/// a Like button that asks first.
class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Column(
      children: [
        const SuspensionBanner(),
        const Text('Home screen'),
        TextButton(
          onPressed: () {
            if (!blockedBySuspension(context, ref, SuspendedAction.like)) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Liked')));
            }
          },
          child: const Text('Like'),
        ),
      ],
    ),
  );
}

void main() {
  late FakeSuspensionService service;

  Future<void> pumpApp(WidgetTester tester, AccountSuspension? active) async {
    service = FakeSuspensionService(active: active);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [suspensionServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          builder: (context, child) => SuspensionGate(child: child),
          home: const _Home(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('not suspended: the app as usual', (tester) async {
    await pumpApp(tester, null);

    expect(find.text('Home screen'), findsOneWidget);
    expect(find.byKey(const Key('suspension_banner')), findsNothing);

    await tester.tap(find.text('Like'));
    await tester.pump();
    expect(find.text('Liked'), findsOneWidget);
  });

  testWidgets('locked: only the suspension screen, with the details', (
    tester,
  ) async {
    await pumpApp(tester, lockedUntilLifted());

    expect(find.text('Home screen'), findsNothing);
    expect(find.text('Account suspended'), findsOneWidget);
    expect(find.text('Harassment or bullying'), findsOneWidget);
    expect(find.text('Abusive messages to other users'), findsOneWidget);
    expect(find.text('When an admin lifts the suspension'), findsOneWidget);
    expect(find.byKey(const Key('suspended_sign_out')), findsOneWidget);
  });

  testWidgets('the lock goes away when the suspension is lifted', (
    tester,
  ) async {
    await pumpApp(tester, lockedUntilLifted());
    expect(find.text('Home screen'), findsNothing);

    await service.change(null);
    await tester.pumpAndSettle();

    expect(find.text('Account suspended'), findsNothing);
    expect(find.text('Home screen'), findsOneWidget);
  });

  testWidgets('a live lock replaces the app at once', (tester) async {
    await pumpApp(tester, null);

    await service.change(lockedUntilLifted());
    await tester.pumpAndSettle();

    expect(find.text('Home screen'), findsNothing);
    expect(find.text('Account suspended'), findsOneWidget);
  });

  testWidgets('Check again asks the database', (tester) async {
    await pumpApp(tester, lockedUntilLifted());
    final calls = service.fetchCalls;
    service.active = null;

    await tester.tap(find.byKey(const Key('suspended_check_again')));
    await tester.pumpAndSettle();

    expect(service.fetchCalls, calls + 1);
    expect(find.text('Home screen'), findsOneWidget);
  });

  testWidgets('restricted: banner, blocked actions explain, details sheet', (
    tester,
  ) async {
    await pumpApp(tester, restrictedFor7Days());

    expect(find.text('Home screen'), findsOneWidget);
    expect(find.byKey(const Key('suspension_banner')), findsOneWidget);
    expect(find.textContaining('until 30 Nov 2026, 7:40 PM'), findsOneWidget);

    await tester.tap(find.text('Like'));
    await tester.pump();
    expect(find.text('Liked'), findsNothing);
    expect(
      find.text(
        "You can't like posts while your account is suspended "
        '(until 30 Nov 2026, 7:40 PM).',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('suspension_banner')));
    await tester.pumpAndSettle();
    expect(find.text('Spam'), findsOneWidget);
    expect(find.text('Posting ads in comments'), findsOneWidget);
    expect(find.text('30 Nov 2026, 7:40 PM'), findsOneWidget);
  });

  testWidgets('the input note says what is blocked', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuspendedInputNote(
            suspension: restrictedFor7Days(),
            action: SuspendedAction.comment,
          ),
        ),
      ),
    );

    expect(
      find.text(
        "You can't comment while your account is suspended "
        '(until 30 Nov 2026, 7:40 PM).',
      ),
      findsOneWidget,
    );
  });
}
