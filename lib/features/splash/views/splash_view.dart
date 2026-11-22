import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/splash/viewmodels/splash_viewmodel.dart';
import 'package:faunawatch/features/welcome/views/welcome_view.dart';
import 'package:faunawatch/features/profile_customization/views/profile_setup_view.dart';
import 'package:faunawatch/features/shell/views/shell_view.dart';

/// Startup screen: plays the fox animation while the session is restored,
/// then fades into the next screen once both are done.
///
/// Its first frame matches the phone's own loading screen (the icon's blue
/// fade with the fox in the middle at [foxSize]), so opening the app looks
/// like one motion: the fox pops, wiggles its head, and the "FaunaWatch"
/// wordmark slides up. If the sign-in check is still running, the fox breathes; a small
/// spinner appears only after [slowCheckDelay]. When the device asks for
/// less motion, the final frame is shown at once.
class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key, this.autoNavigate = true});

  final bool autoNavigate;

  /// Length of the intro: pop, head wiggle, then the name.
  static const introDuration = Duration(milliseconds: 1500);

  /// How long the sign-in check may take before a spinner is shown.
  static const slowCheckDelay = Duration(seconds: 3);

  /// The fox's size in points; the phone's loading screen uses the same size.
  static const foxSize = 144.0;

  /// Width of the "FaunaWatch" wordmark under the fox (about 84 points tall).
  static const wordmarkWidth = 200.0;

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: SplashView.introDuration,
  )..addStatusListener(_onIntroStatus);

  /// Slow, gentle pulse while waiting for the sign-in check after the intro.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  final _introDone = Completer<void>();
  Timer? _slowTimer;
  bool _slow = false;
  bool _started = false;
  bool _reduceMotion = false;

  // Pop: a quick grow with a small bounce back to the loading-screen size.
  late final Animation<double> _pop = TweenSequence<double>([
    _step(1, 1.12, Curves.easeOut, 45),
    _step(1.12, 0.96, Curves.easeInOut, 30),
    _step(0.96, 1, Curves.easeOut, 25),
  ]).animate(CurvedAnimation(parent: _intro, curve: const Interval(0, 0.35)));

  // Wiggle: a happy head tilt, side to side twice (angles in radians).
  late final Animation<double> _wiggle = TweenSequence<double>(
    [
      _step(0, 0.1, Curves.easeOut, 1),
      _step(0.1, -0.1, Curves.easeInOut, 2),
      _step(-0.1, 0.07, Curves.easeInOut, 2),
      _step(0.07, -0.05, Curves.easeInOut, 2),
      _step(-0.05, 0, Curves.easeIn, 1),
    ],
  ).animate(CurvedAnimation(parent: _intro, curve: const Interval(0.35, 0.78)));

  // Name: slides up gently and fades in under the fox.
  late final Animation<double> _nameOpacity = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.6, 1, curve: Curves.easeOut),
  );
  // Starts about 30 points below its place (0.35 of the wordmark's height).
  late final Animation<Offset> _nameSlide =
      Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _intro,
          curve: const Interval(0.6, 1, curve: Curves.easeOutCubic),
        ),
      );

  static TweenSequenceItem<double> _step(
    double from,
    double to,
    Curve curve,
    double weight,
  ) => TweenSequenceItem(
    tween: Tween<double>(begin: from, end: to).chain(CurveTween(curve: curve)),
    weight: weight,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _breath.stop();
    if (_started) return;
    _started = true;
    if (_reduceMotion) {
      _intro.value = 1; // Final frame at once; also completes _introDone.
    } else {
      _intro.forward();
    }
    if (widget.autoNavigate) _startInitialization();
  }

  void _onIntroStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _introDone.isCompleted) return;
    _introDone.complete();
    // Still checking the sign-in: breathe instead of standing still.
    if (!_reduceMotion &&
        ref.read(splashViewModelProvider) == SplashState.initializing) {
      _breath.repeat(reverse: true);
    }
  }

  Future<void> _startInitialization() async {
    _slowTimer?.cancel();
    if (_slow) setState(() => _slow = false); // Retry after a slow attempt.
    _slowTimer = Timer(SplashView.slowCheckDelay, () {
      if (mounted) setState(() => _slow = true);
    });

    await ref
        .read(splashViewModelProvider.notifier)
        .initializeApp(introFinished: _introDone.future);
    _slowTimer?.cancel();

    if (!mounted) return;
    final state = ref.read(splashViewModelProvider);
    if (state == SplashState.failed) {
      _breath.stop();
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            switch (state) {
              SplashState.home => const ShellView(),
              SplashState.profileSetup => const ProfileSetupView(),
              _ => const WelcomeView(),
            },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _intro.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(splashViewModelProvider);
    final failed = state == SplashState.failed;
    final showSpinner = _slow && state == SplashState.initializing;

    return Scaffold(
      backgroundColor: AppColors.splashFadeBottom,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.splashFadeTop, AppColors.splashFadeBottom],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The fox sits in the exact middle, like on the loading screen;
            // everything else hangs below it.
            final belowFox =
                constraints.maxHeight / 2 + SplashView.foxSize / 2 + 20;
            return Stack(
              children: [
                Center(child: _buildFox()),
                Positioned(
                  left: 24,
                  right: 24,
                  top: belowFox,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _nameOpacity,
                        child: SlideTransition(
                          position: _nameSlide,
                          child: Image.asset(
                            AppAssets.splashWordmark,
                            width: SplashView.wordmarkWidth,
                            fit: BoxFit.contain,
                            semanticLabel: 'FaunaWatch',
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (failed)
                        _RestoreFailed(onRetry: _startInitialization)
                      else if (showSpinner)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFox() {
    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _breath]),
      builder: (context, child) {
        final breath = 1 + 0.04 * Curves.easeInOut.transform(_breath.value);
        return Transform.rotate(
          angle: _wiggle.value,
          alignment: Alignment.bottomCenter,
          child: Transform.scale(scale: _pop.value * breath, child: child),
        );
      },
      child: Image.asset(
        AppAssets.splashFox,
        width: SplashView.foxSize,
        height: SplashView.foxSize,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// "Couldn't restore your session" message with a Retry button, in white so
/// it reads well on the blue background.
class _RestoreFailed extends StatelessWidget {
  const _RestoreFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Could not restore your session. Please try again.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            textStyle: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white,
            ),
          ),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
