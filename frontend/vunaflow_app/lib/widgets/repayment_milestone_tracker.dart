import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/validators.dart';

/// 5-Milestone Segmented Repayment Progress Tracker Widget.
/// Each of the 5 segments represents a 20% milestone with its own distinct status.
class RepaymentMilestoneTracker extends StatelessWidget {
  final double requestedAmount;
  final double paidAmount;
  final bool isOverdue;
  final bool isDark;
  final bool compact;

  const RepaymentMilestoneTracker({
    super.key,
    required this.requestedAmount,
    required this.paidAmount,
    this.isOverdue = false,
    this.isDark = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = requestedAmount > 0 ? (paidAmount / requestedAmount).clamp(0.0, 1.0) : 0.0;
    final int filledSegments = (progress * 5).floor().clamp(0, 5);
    final bool isFullyRepaid = paidAmount >= requestedAmount && requestedAmount > 0;

    final primaryGreen = isDark ? const Color(0xFF2ECC71) : const Color(0xFF16A34A);
    final activeGreen = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    final overdueRed = isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
    final pendingGrey = isDark ? const Color(0xFF223C2D) : const Color(0xFFE5E7EB);
    final textSub = isDark ? const Color(0xFF9EBAA9) : const Color(0xFF6B7280);
    final textTitle = isDark ? const Color(0xFFF4F6F0) : const Color(0xFF1F2937);

    final milestones = [
      (pct: '20%', fraction: 0.2),
      (pct: '40%', fraction: 0.4),
      (pct: '60%', fraction: 0.6),
      (pct: '80%', fraction: 0.8),
      (pct: '100%', fraction: 1.0),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 5-segment progress bar
        Row(
          children: List.generate(5, (i) {
            Color segColor;
            if (isFullyRepaid || progress >= milestones[i].fraction) {
              segColor = primaryGreen;
            } else if (i == filledSegments && progress > 0) {
              segColor = isOverdue ? overdueRed : activeGreen;
            } else {
              segColor = pendingGrey;
            }

            return Expanded(
              child: Container(
                height: compact ? 5 : 6,
                margin: EdgeInsets.only(right: i == 4 ? 0 : 5),
                decoration: BoxDecoration(
                  color: segColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),

        // 5 Milestone Individual Statuses
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (i) {
            final milestone = milestones[i];
            final bool isPaid = isFullyRepaid || progress >= milestone.fraction;
            final bool isCurrent = !isPaid && i == filledSegments;

            String statusText;
            Color statusColor;
            String emoji;

            if (isPaid) {
              statusText = 'Paid';
              statusColor = primaryGreen;
              emoji = '✅';
            } else if (isCurrent) {
              if (isOverdue) {
                statusText = 'Overdue';
                statusColor = overdueRed;
                emoji = '🔴';
              } else {
                statusText = 'Active';
                statusColor = activeGreen;
                emoji = '🟢';
              }
            } else {
              statusText = 'Pending';
              statusColor = textSub;
              emoji = '⚪';
            }

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 4 ? 0 : 4),
                child: Column(
                  children: [
                    Text(
                      milestone.pct,
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: compact ? 10 : 11,
                        fontWeight: FontWeight.w700,
                        color: isPaid || isCurrent ? textTitle : textSub,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      compact ? emoji : '$emoji $statusText',
                      style: GoogleFonts.publicSans(
                        fontSize: compact ? 10 : 10.5,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }),
        ),

        if (!compact) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Paid: ${fmtKsh(paidAmount)}',
                style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: textSub),
              ),
              Text(
                'Goal: ${fmtKsh(requestedAmount)}',
                style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: textTitle),
              ),
            ],
          ),
        ],
      ],
    );
  }
}