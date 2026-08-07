import 'package:flutter/material.dart';

/// Wraps page sections with consistent max-width, padding, and background,
/// so the landing page reads well on both mobile and wide desktop/web views.
class SectionContainer extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  const SectionContainer({
    super.key,
    required this.child,
    this.backgroundColor,
    this.padding,
    this.maxWidth = 1100,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final horizontalPad = width < 700 ? 20.0 : 48.0;

    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: padding ??
          EdgeInsets.symmetric(horizontal: horizontalPad, vertical: width < 700 ? 48 : 80),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
