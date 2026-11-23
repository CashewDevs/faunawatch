import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:faunawatch/features/app_update/viewmodels/app_update_viewmodel.dart';
import 'package:faunawatch/features/app_update/views/widgets/update_available_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// The "New version available" card at the top of the Feed.
///
/// Starts the quiet automatic update check when first shown. About half a
/// second after a newer version is found, the card slides down from under
/// the search bar with a soft bounce and its arrow bobs twice; "Not now"
/// slides it back up. Everything is instant when the device asks for less
/// motion. It takes no space while there is nothing to offer.
class AppUpdateBanner extends ConsumerStatefulWidget {
  const AppUpdateBanner({super.key});

  /// How long the card waits, then slides in (the first part is the wait).
  static const enterDuration = Duration(milliseconds: 1000);

  @override
  ConsumerState<AppUpdateBanner> createState() => _AppUpdateBannerState();
}

class _AppUpdateBannerState extends ConsumerState<AppUpdateBanner>
    with TickerProviderStateMixin {
  // The first 45 % of [AppUpdateBanner.enterDuration] is the pause.
  static const _pause = 0.45;

  late final AnimationController _show = AnimationController(
    vsync: this,
    duration: AppUpdateBanner.enterDuration,
  );
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final Animation<double> _reveal = CurvedAnimation(
    parent: _show,
    curve: const Interval(_pause, 0.85, curve: Curves.easeOutCubic),
  );
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, -0.35), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _show,
          curve: const Interval(_pause, 1, curve: Curves.easeOutBack),
        ),
      );
  late final Animation<double> _arrowLift = TweenSequence<double>([
    for (var i = 0; i < 2; i++) ...[
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -6.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -6.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 1.4,
      ),
    ],
  ]).animate(_bob);

  /// The version on the card; kept while it slides away.
  AppVersion? _shown;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _show.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_reduceMotion) {
        _bob.forward(from: 0);
      }
    });
    // Already found earlier in this session (e.g. the Feed was rebuilt).
    final current = ref.read(appUpdateViewModelProvider).notice;
    if (current != null) {
      _shown = current;
      _show.value = 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(appUpdateViewModelProvider.notifier).autoCheck();
    });
  }

  @override
  void dispose() {
    _show.dispose();
    _bob.dispose();
    super.dispose();
  }

  void _onNoticeChanged(AppVersion? previous, AppVersion? next) {
    if (next != null) {
      final wasHidden = _shown == null;
      setState(() => _shown = next);
      if (_reduceMotion) {
        _show.value = 1;
      } else if (wasHidden) {
        _show.forward(from: 0);
      }
    } else if (_shown != null) {
      _hide();
    }
  }

  Future<void> _hide() async {
    _bob.stop();
    if (!_reduceMotion) {
      try {
        // Back to the end of the pause, where the card is fully hidden.
        await _show
            .animateBack(
              _pause,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInCubic,
            )
            .orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    _show.value = 0;
    setState(() => _shown = null);
  }

  Future<void> _update() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ready = await ref
        .read(appUpdateViewModelProvider.notifier)
        .loadNewerRelease();
    if (!mounted) return;
    if (ready) {
      await showUpdateAvailableDialog(context);
      return;
    }
    final upToDate =
        ref.read(appUpdateViewModelProvider).status ==
        UpdateCheckStatus.upToDate;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          upToDate
              ? 'FaunaWatch is up to date.'
              : "Couldn't check for updates. Try again from Settings.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppVersion?>(
      appUpdateViewModelProvider.select((state) => state.notice),
      _onNoticeChanged,
    );
    final state = ref.watch(appUpdateViewModelProvider);
    final shown = _shown;
    if (shown == null) return const SizedBox(width: double.infinity);

    return SizeTransition(
      sizeFactor: _reveal,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _reveal,
        child: SlideTransition(
          position: _slide,
          child: _UpdateCard(
            version: shown,
            headline: state.noticeHeadline,
            isChecking: state.isChecking,
            arrowLift: _arrowLift,
            onUpdate: _update,
            onNotNow: ref
                .read(appUpdateViewModelProvider.notifier)
                .dismissNotice,
          ),
        ),
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.version,
    required this.headline,
    required this.isChecking,
    required this.arrowLift,
    required this.onUpdate,
    required this.onNotNow,
  });

  final AppVersion version;
  final String? headline;
  final bool isChecking;
  final Animation<double> arrowLift;
  final VoidCallback onUpdate;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    // The palette's blue, darkened so white text stays readable in every
    // palette and in dark mode.
    final accent = HSLColor.fromColor(
      AppPaletteColors.of(context).shellHeaderBlue,
    );
    final top = accent.withLightness(0.40).toColor();
    final bottom = accent.withLightness(0.27).toColor();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [top, bottom],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: bottom.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: AnimatedBuilder(
                      animation: arrowLift,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, arrowLift.value),
                        child: child,
                      ),
                      child: const Icon(
                        Icons.arrow_circle_up_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'New version available',
                          style: GoogleFonts.dmSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'FaunaWatch ${version.label} is ready',
                          style: GoogleFonts.dmSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                        if (headline != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            headline!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 13.5,
                              height: 1.35,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: isChecking ? null : onUpdate,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: bottom,
                        disabledBackgroundColor: Colors.white.withValues(
                          alpha: 0.85,
                        ),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isChecking
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: bottom,
                              ),
                            )
                          : Text(
                              'Update now',
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onNotNow,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.9),
                      minimumSize: const Size(0, 50),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(
                      'Not now',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
