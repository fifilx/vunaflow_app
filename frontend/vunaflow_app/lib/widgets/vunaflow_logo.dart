import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// VunaFlow's brand mark from redesign: rounded tile with shamba gradient and leaf sprout icon
class VunaFlowLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;

  const VunaFlowLogo({super.key, this.size = 36, this.showWordmark = false});

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.shamba700, AppColors.shamba900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: AppColors.shamba900.withValues(alpha: 0.15),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.spa_outlined,
          color: AppColors.goldPale,
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
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}
