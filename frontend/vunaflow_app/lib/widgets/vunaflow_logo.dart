import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// VunaFlow's brand mark from redesign: rounded tile with shamba gradient and leaf sprout icon
class VunaFlowLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final Color? textColor;

  const VunaFlowLogo({
    super.key,
    this.size = 36,
    this.showWordmark = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? const Color(0xFFF4F6F0) : const Color(0xFF1F281E);
    final effectiveColor = textColor ?? defaultColor;

    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2ECC71), Color(0xFF133826)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF133826).withValues(alpha: 0.25),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.spa_outlined,
          color: const Color(0xFFF1DDAF),
          size: size * 0.55,
        ),
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.28),
        Text(
          'VunaFlow',
          style: GoogleFonts.fraunces(
            fontSize: size * 0.58,
            fontWeight: FontWeight.w700,
            color: effectiveColor,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
