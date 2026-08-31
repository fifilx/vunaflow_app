import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/logout_button.dart';
import '../../widgets/vunaflow_logo.dart';
import '../../widgets/theme_toggle_button.dart';
import 'notifications_screen.dart';
import 'loan_detail_screen.dart';
import 'loan_tracking_screen.dart';

class ClientHomeTab extends StatefulWidget {
  const ClientHomeTab({super.key});

  @override
  State<ClientHomeTab> createState() => _ClientHomeTabState();
}

class _ClientHomeTabState extends State<ClientHomeTab> {
  bool _loading = true;
  List<dynamic> _loans = [];
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.get('/api/loans/mine'),
        ApiService.get('/api/notifications'),
      ]);
      setState(() {
        _loans = results[0] as List<dynamic>;
        _unreadNotifications = (results[1] as Map<String, dynamic>)['unread_count'] ?? 0;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C1610) : const Color(0xFFF9F8F5);
    final cardBg = isDark ? const Color(0xFF14241B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF223C2D) : const Color(0xFFE5E7EB);
    final textTitle = isDark ? const Color(0xFFF4F6F0) : const Color(0xFF1F2937);
    final textSub = isDark ? const Color(0xFF9EBAA9) : const Color(0xFF6B7280);

    final activeLoans = _loans.where((l) => !['rejected', 'disbursed'].contains(l['status'])).length;
    final approved = _loans.where((l) => l['status'] == 'approved' || l['status'] == 'disbursed').length;
    final totalRequested = _loans.fold<double>(0, (sum, l) => sum + double.parse(l['amount_requested'].toString()));

    // Get the representative loan for repayment hero card
    final activeOrDisbursedLoan = _loans.firstWhere(
      (l) => l['status'] == 'disbursed' || l['status'] == 'approved',
      orElse: () => _loans.isNotEmpty ? _loans.first : null,
    );

    double reqAmt = 300000;
    double pdAmt = 300000;
    double pct = 1.0;
    bool isFullyRepaid = true;
    String statusChipText = 'FULLY REPAID';

    if (activeOrDisbursedLoan != null) {
      reqAmt = double.tryParse(activeOrDisbursedLoan['amount_requested'].toString()) ?? 0.0;
      pdAmt = double.tryParse((activeOrDisbursedLoan['amount_paid'] ?? 0).toString()) ?? 0.0;
      final remAmt = (reqAmt - pdAmt).clamp(0, double.infinity);
      pct = reqAmt > 0 ? (pdAmt / reqAmt).clamp(0.0, 1.0) : 0.0;
      isFullyRepaid = remAmt <= 0 && pdAmt > 0;
      if (isFullyRepaid) {
        statusChipText = 'FULLY REPAID';
      } else if (activeOrDisbursedLoan['status'] == 'disbursed') {
        statusChipText = 'ACTIVE LOAN';
      } else {
        statusChipText = statusLabel(activeOrDisbursedLoan['status']).toUpperCase();
      }
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const VunaFlowLogo(size: 30, showWordmark: true),
        actions: [
          const ThemeToggleButton(),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162A1F) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: borderCol),
            ),
            child: IconButton(
              icon: Badge(
                label: Text('$_unreadNotifications', style: const TextStyle(fontSize: 10)),
                isLabelVisible: _unreadNotifications > 0,
                backgroundColor: const Color(0xFFB03F2E),
                child: Icon(Icons.notifications_none_outlined, color: isDark ? const Color(0xFFF4F6F0) : const Color(0xFF1F2937), size: 18),
              ),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ).then((_) => _loadData()),
            ),
          ),
          const LogoutButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                children: [
                  // Hero Repayment / Status Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF10261A) : const Color(0xFF133826),
                      borderRadius: BorderRadius.circular(16),
                      border: isDark ? Border.all(color: const Color(0xFF1E4833)) : null,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF133826).withValues(alpha: isDark ? 0.3 : 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF163E27) : const Color(0xFFD4EDDA),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                statusChipText,
                                style: GoogleFonts.publicSans(
                                  color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF155724),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Text(
                              '${(pct * 100).toInt()}% Completed',
                              style: GoogleFonts.publicSans(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          fmtKsh(reqAmt),
                          style: GoogleFonts.publicSans(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isFullyRepaid
                              ? 'Repaid of ${fmtKsh(reqAmt)} Total Loan'
                              : '${fmtKsh(pdAmt)} Paid of ${fmtKsh(reqAmt)} Total Loan',
                          style: GoogleFonts.publicSans(
                            color: const Color(0xFFB5D5C5),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 6,
                            backgroundColor: const Color(0xFF1E4833),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2ECC71)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Loan Summary Section
                  Text(
                    'Loan Summary',
                    style: GoogleFonts.publicSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textTitle,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryStatCard(
                          cardBg: cardBg,
                          borderCol: borderCol,
                          textSub: textSub,
                          valueWidget: Text(
                            '$activeLoans',
                            style: GoogleFonts.publicSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: textTitle,
                            ),
                          ),
                          label: 'Active',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryStatCard(
                          cardBg: cardBg,
                          borderCol: borderCol,
                          textSub: textSub,
                          valueWidget: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$approved',
                                style: GoogleFonts.publicSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: textTitle,
                                ),
                              ),
                            ],
                          ),
                          label: 'Approved',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryStatCard(
                          cardBg: cardBg,
                          borderCol: borderCol,
                          textSub: textSub,
                          valueWidget: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(totalRequested / 1000).toStringAsFixed(0)}K',
                                style: GoogleFonts.publicSans(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: textTitle,
                                ),
                              ),
                            ],
                          ),
                          label: 'Total Req.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Recent Applications Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Applications',
                        style: GoogleFonts.publicSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textTitle,
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoanTrackingScreen()),
                        ).then((_) => _loadData()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            'View All',
                            style: GoogleFonts.publicSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loans.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderCol),
                      ),
                      child: Center(
                        child: Text(
                          'No loan applications yet. Tap "+ New Loan" to apply.',
                          style: GoogleFonts.publicSans(color: textSub, fontSize: 13.5),
                        ),
                      ),
                    )
                  else
                    ..._loans.take(3).map((loan) {
                      final isCrop = (loan['purpose'] ?? '').toString().toLowerCase().contains('plant') ||
                          (loan['purpose'] ?? '').toString().toLowerCase().contains('seed') ||
                          (loan['purpose'] ?? '').toString().toLowerCase().contains('maize');

                      return _RecentLoanCard(
                        loan: loan,
                        isCrop: isCrop,
                        cardBg: cardBg,
                        borderCol: borderCol,
                        textTitle: textTitle,
                        textSub: textSub,
                        isDark: isDark,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loan['id'])),
                          ).then((_) => _loadData());
                        },
                      );
                    }),
                  const SizedBox(height: 90),
                ],
              ),
      ),
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  final Widget valueWidget;
  final String label;
  final Color cardBg;
  final Color borderCol;
  final Color textSub;

  const _SummaryStatCard({
    required this.valueWidget,
    required this.label,
    required this.cardBg,
    required this.borderCol,
    required this.textSub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          valueWidget,
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.publicSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textSub,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentLoanCard extends StatelessWidget {
  final Map<String, dynamic> loan;
  final bool isCrop;
  final VoidCallback onTap;
  final Color cardBg;
  final Color borderCol;
  final Color textTitle;
  final Color textSub;
  final bool isDark;

  const _RecentLoanCard({
    required this.loan,
    required this.isCrop,
    required this.onTap,
    required this.cardBg,
    required this.borderCol,
    required this.textTitle,
    required this.textSub,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final status = loan['status'] as String? ?? 'submitted';
    final amount = double.tryParse(loan['amount_requested'].toString()) ?? 0.0;
    final purpose = loan['purpose'] as String? ?? 'Agricultural Loan';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark
                        ? (isCrop ? const Color(0xFF163E27) : const Color(0xFF382D16))
                        : (isCrop ? const Color(0xFFE8F5E9) : const Color(0xFFFEF3C7)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      isCrop ? Icons.eco_outlined : Icons.agriculture_outlined,
                      size: 20,
                      color: isCrop ? const Color(0xFF10B981) : const Color(0xFFD97706),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fmtKsh(amount),
                        style: GoogleFonts.publicSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textTitle,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        purpose,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.publicSans(
                          fontSize: 12.5,
                          color: textSub,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF163E27) : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel(status),
                    style: GoogleFonts.publicSans(
                      color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

