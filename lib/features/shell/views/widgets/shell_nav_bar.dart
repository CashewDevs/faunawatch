import 'dart:math' as math;

import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';

const double _addButtonSize = 56;

/// How far the Add post button rises above the top edge of the bar.
const double _addButtonRise = 22;
const double _notchHalfWidth = 48;
const double _notchDepth = 38;

/// Height of a tab (and of the selection squircle behind it).
const double _itemHeight = 50;
const double _maxSquircleWidth = 68;

/// How long the squircle takes to glide to the newly selected tab.
const Duration _selectionDuration = Duration(milliseconds: 250);

/// Colours of the bar's picture icons, so the Profile icon matches them.
const Color _iconBlue = AppColors.navLabelBlue;
const Color _iconYellow = AppColors.messagesHeaderUnderline;

/// Custom bottom navigation bar: Feed · Map | + | Chats · Profile, around a
/// raised Add post button that sits in a notch at the top of the bar.
///
/// The selected tab sits in a rounded square (squircle) that glides to the
/// next tab when the selection changes, while the icons fade between their
/// outline and filled versions. Notifications open from the bell in the top
/// bar.
class ShellNavBar extends StatelessWidget {
  const ShellNavBar({
    super.key,
    required this.currentDestination,
    required this.onSelectDestination,
  });

  final ShellDestination currentDestination;
  final ValueChanged<ShellDestination> onSelectDestination;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _selectionDuration;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: _addButtonRise),
            child: CustomPaint(
              painter: _NotchedBarPainter(
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderColor: isDark
                    ? AppPaletteColors.of(context).resolve(
                        const Color(0xFF334155),
                        Theme.of(context).colorScheme.primaryContainer,
                      )
                    : const Color(0xFFD6E2EE),
                shadowColor: Colors.black.withValues(
                  alpha: isDark ? 0.35 : 0.08,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: SizedBox(
                  height: _itemHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Each side of the Add post button gets half of the
                      // rest of the bar, so the gap stays under the button.
                      final side =
                          (constraints.maxWidth - _notchHalfWidth * 2) / 2;
                      final itemWidth = side / 2;
                      final squircleWidth = math.min(
                        itemWidth - 4,
                        _maxSquircleWidth,
                      );
                      final center = switch (currentDestination) {
                        ShellDestination.feed => itemWidth / 2,
                        ShellDestination.map => itemWidth * 1.5,
                        ShellDestination.chats =>
                          side + _notchHalfWidth * 2 + itemWidth / 2,
                        ShellDestination.profile =>
                          side + _notchHalfWidth * 2 + itemWidth * 1.5,
                        ShellDestination.addPost => null,
                      };
                      return Stack(
                        children: [
                          if (center != null)
                            AnimatedPositioned(
                              duration: duration,
                              curve: Curves.easeOutCubic,
                              left: center - squircleWidth / 2,
                              top: 0,
                              width: squircleWidth,
                              height: _itemHeight,
                              child: _SelectionSquircle(isDark: isDark),
                            ),
                          Row(
                            children: [
                              _buildPictureItem(
                                context: context,
                                destination: ShellDestination.feed,
                                label: 'Feed',
                                unpressedAsset: AppAssets.navFeedUnpressed,
                                pressedAsset: AppAssets.navFeedPressed,
                                isDark: isDark,
                                duration: duration,
                              ),
                              _buildPictureItem(
                                context: context,
                                destination: ShellDestination.map,
                                label: 'Map',
                                unpressedAsset: AppAssets.navMapUnpressed,
                                pressedAsset: AppAssets.navMapPressed,
                                isDark: isDark,
                                duration: duration,
                              ),
                              // Keeps the items clear of the Add post button.
                              const SizedBox(width: _notchHalfWidth * 2),
                              _buildPictureItem(
                                context: context,
                                destination: ShellDestination.chats,
                                label: 'Chats',
                                unpressedAsset: AppAssets.navChatsUnpressed,
                                pressedAsset: AppAssets.navChatsPressed,
                                isDark: isDark,
                                duration: duration,
                              ),
                              _buildItem(
                                context: context,
                                destination: ShellDestination.profile,
                                label: 'Profile',
                                isDark: isDark,
                                duration: duration,
                                icon: (isSelected) => Icon(
                                  isSelected
                                      ? Icons.person_rounded
                                      : Icons.person_outline_rounded,
                                  key: ValueKey(isSelected),
                                  color: isSelected ? _iconYellow : _iconBlue,
                                  size: 27,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: _AddPostButton(
              isSelected: currentDestination == ShellDestination.addPost,
              onTap: () => onSelectDestination(ShellDestination.addPost),
            ),
          ),
        ],
      ),
    );
  }

  /// A tab drawn with the bar's outline (unselected) and filled (selected)
  /// pictures.
  Widget _buildPictureItem({
    required BuildContext context,
    required ShellDestination destination,
    required String label,
    required String unpressedAsset,
    required String pressedAsset,
    required bool isDark,
    required Duration duration,
  }) {
    return _buildItem(
      context: context,
      destination: destination,
      label: label,
      isDark: isDark,
      duration: duration,
      icon: (isSelected) => Image.asset(
        isSelected ? pressedAsset : unpressedAsset,
        key: ValueKey(isSelected),
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required ShellDestination destination,
    required String label,
    required bool isDark,
    required Duration duration,
    required Widget Function(bool isSelected) icon,
  }) {
    final isSelected = currentDestination == destination;

    return Expanded(
      child: Semantics(
        container: true,
        button: true,
        label: label,
        selected: isSelected,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => onSelectDestination(destination),
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 27,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: duration,
                    child: icon(isSelected),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: isDark
                      ? (isSelected ? Colors.white : const Color(0xFF94A3B8))
                      : AppPaletteColors.of(context).navLabelBlue,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rounded square behind the selected tab's icon and label.
class _SelectionSquircle extends StatelessWidget {
  const _SelectionSquircle({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteColors.of(context);
    return DecoratedBox(
      key: const Key('nav_selection_squircle'),
      decoration: ShapeDecoration(
        color: isDark ? const Color(0xFF334155) : palette.navActiveBackground,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: BorderSide(
            color: isDark
                ? palette.resolve(
                    const Color(0xFF64748B),
                    Theme.of(context).colorScheme.primary,
                  )
                : palette.navActiveBorder,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

/// Round brand-colored button for creating a post.
class _AddPostButton extends StatelessWidget {
  const _AddPostButton({required this.isSelected, required this.onTap});

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'Add post',
      selected: isSelected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: _addButtonSize,
          height: _addButtonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppPaletteColors.of(context).profileButtonGradientStart,
                AppPaletteColors.of(context).profileButtonGradientEnd,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppPaletteColors.of(
                  context,
                ).profileButtonGradientEnd.withValues(alpha: 0.45),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Icon(
            Icons.add_rounded,
            color: AppPaletteColors.of(context).resolve(
              AppColors.shellHeaderBlue,
              Theme.of(context).colorScheme.onPrimary,
            ),
            size: 36,
          ),
        ),
      ),
    );
  }
}

/// Paints the bar's rounded body with a smooth dip for the Add post button.
class _NotchedBarPainter extends CustomPainter {
  const _NotchedBarPainter({
    required this.fillColor,
    required this.borderColor,
    required this.shadowColor,
  });

  final Color fillColor;
  final Color borderColor;
  final Color shadowColor;

  static const double _radius = 20;

  Path _barPath(Size size) {
    final center = size.width / 2;
    return Path()
      ..moveTo(_radius, 0)
      ..lineTo(center - _notchHalfWidth, 0)
      ..cubicTo(center - 32, 0, center - 44, _notchDepth, center, _notchDepth)
      ..cubicTo(
        center + 44,
        _notchDepth,
        center + 32,
        0,
        center + _notchHalfWidth,
        0,
      )
      ..lineTo(size.width - _radius, 0)
      ..arcToPoint(
        Offset(size.width, _radius),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(size.width, size.height - _radius)
      ..arcToPoint(
        Offset(size.width - _radius, size.height),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(_radius, size.height)
      ..arcToPoint(
        Offset(0, size.height - _radius),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(0, _radius)
      ..arcToPoint(
        const Offset(_radius, 0),
        radius: const Radius.circular(_radius),
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _barPath(size);
    canvas.drawPath(
      path.shift(const Offset(0, 4)),
      Paint()
        ..color = shadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_NotchedBarPainter oldDelegate) =>
      fillColor != oldDelegate.fillColor ||
      borderColor != oldDelegate.borderColor ||
      shadowColor != oldDelegate.shadowColor;
}
