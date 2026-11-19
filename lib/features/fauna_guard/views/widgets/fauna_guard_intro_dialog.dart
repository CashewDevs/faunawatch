import 'dart:math' as math;
import 'package:flutter/material.dart';

/// An opt-in explanation shown before any location or notification prompt.
class FaunaGuardIntroDialog extends StatelessWidget {
  const FaunaGuardIntroDialog({super.key});

  static Future<bool?> show(BuildContext context) => showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 520),
    pageBuilder: (_, _, _) => const FaunaGuardIntroDialog(),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FaunaGuardFlipTransition(animation: animation, child: child),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Close FaunaGuard introduction',
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.onPrimaryContainer,
                      child: const Icon(Icons.shield_outlined, size: 38),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Meet FaunaGuard',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'A little awareness for the path ahead.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const _IntroStep(
                      Icons.my_location,
                      'Moves with you',
                      'The map follows your live location while FaunaGuard watches all approved wildlife reports.',
                    ),
                    const SizedBox(height: 18),
                    const _IntroStep(
                      Icons.notifications_active_outlined,
                      'A heads-up nearby',
                      'Get “Getting closer” alerts within 1 km and “Nearby” alerts within 500 m of an approximate report pin. Each report alerts once per band while enabled.',
                    ),
                    const SizedBox(height: 18),
                    const _IntroStep(
                      Icons.lock_outline,
                      'On your terms',
                      'Location is used on this device, including in the background and when locked. Android shows an ongoing notification; iOS shows a location indicator. Tap the shield again to stop.',
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Report locations are approximate (about 1 km precision), so these distances are estimates. Wildlife may have moved. Keep a safe distance. Tracking uses battery and stops if the app is closed or stopped by your device.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.shield_outlined),
                    label: const Text('Turn on FaunaGuard'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Not now'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroStep extends StatelessWidget {
  const _IntroStep(this.icon, this.title, this.body);
  final IconData icon;
  final String title, body;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(body),
          ],
        ),
      ),
    ],
  );
}

/// Two faces rotate around the vertical axis without mirrored text. The back
/// carries the shield; the explanation becomes interactive after the midpoint.
class FaunaGuardFlipTransition extends StatelessWidget {
  const FaunaGuardFlipTransition({
    super.key,
    required this.animation,
    required this.child,
  });
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final progress = MediaQuery.disableAnimationsOf(context)
          ? 1.0
          : Curves.easeInOutCubic.transform(animation.value);
      final front = progress >= 0.5;
      return Opacity(
        opacity: animation.value,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(front ? (1 - progress) * math.pi : -progress * math.pi),
          child: front
              ? child
              : Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const SizedBox(
                    width: 280,
                    height: 280,
                    child: Icon(Icons.shield_outlined, size: 90),
                  ),
                ),
        ),
      );
    },
  );
}
