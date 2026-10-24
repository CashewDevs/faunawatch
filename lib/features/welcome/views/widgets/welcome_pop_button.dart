import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A tactile neobrutalist/pop button featuring a bold black outline,
/// hard drop shadow, and micro-press interactive feedback.
class WelcomePopButton extends StatefulWidget {
  const WelcomePopButton({
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
    super.key,
    this.gradientColors,
    this.textColor = Colors.black,
    this.height = 56,
  });

  final String label;
  final Color backgroundColor;
  final List<Color>? gradientColors;
  final Color textColor;
  final double height;
  final VoidCallback onPressed;

  @override
  State<WelcomePopButton> createState() => _WelcomePopButtonState();
}

class _WelcomePopButtonState extends State<WelcomePopButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    const double borderRadius = 32;
    const double borderWidth = 2.5;

    final double shadowOffsetY = _isPressed ? 1.5 : 4.0;
    final double shadowOffsetX = _isPressed ? 1.0 : 2.5;
    final double translateY = _isPressed ? 2.5 : 0.0;
    final double translateX = _isPressed ? 1.5 : 0.0;

    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: Transform.translate(
        offset: Offset(translateX, translateY),
        child: Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            gradient: widget.gradientColors != null
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: widget.gradientColors!,
                  )
                : null,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.black, width: borderWidth),
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                offset: Offset(shadowOffsetX, shadowOffsetY),
                blurRadius: 0,
                spreadRadius: 0,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: widget.textColor,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
