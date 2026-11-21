import 'package:flutter/material.dart';

/// Adds an accessible profile action without changing identity typography.
class ProfileLink extends StatelessWidget {
  const ProfileLink({
    super.key,
    required this.name,
    required this.child,
    this.onTap,
  });

  final String name;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Semantics(
      button: true,
      label: "View $name's profile",
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: child,
      ),
    );
  }
}
