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
import 'loan_application_screen.dart';
import 'assistant_screen.dart';

class ClientHomeTab extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;
  const ClientHomeTab({super.key, this.onNavigateToTab});

  @override
  State<ClientHomeTab> createState() => _ClientHomeTabState();
}

class _ClientHomeTabState extends State<ClientHomeTab> {
  bool _loading = true;
  List<dynamic> _loans = [];
  int _unreadNotifications = 0;
  final PageController _pageController = PageController();
  int _currentCardIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

    // Compute metrics
    final activeLoansList = _loans.where((l) => l['status'] == 'disbursed' || l['status'] == 'approved').toList();
    final activeLoansCount = _loans.where((l) => !['rejected', 'disbursed'].contains(l['status'])).length;
    final approvedLoansCount = _loans.where((l) => l['status'] == 'approved' || l['status'] == 'disbursed').length;
    final totalRequested = _loans.fold<double>(0, (sum, l) => sum + (double.tryParse(l['amount_requested']?.toString() ?? '0') ?? 0.0));

    final totalDisbursed = _loans
        .where((l) => l['status'] == 'disbursed')
        .fold<double>(0, (sum, l) => sum + (double.tryParse(l['amount_requested']?.toString() ?? '0') ?? 0.0));

    final totalPaid = _loans.fold<double>(0, (sum, l) => sum + (double.tryParse(l['amount_paid']?.toString() ?? '0') ?? 0.0));

    // Categorize loans
    final List<Map<String, dynamic>> loanInfos = _loans.map((l) => l as Map<String, dynamic>).toList();
    final overdueLoans = loanInfos.where((l) => _getLoanStatusInfo(l, isDark).isOverdue).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: MediaQuery.sizeOf(context).width >= 840
            ? Text(
                'Dashboard Overview',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textTitle,
                ),
              )
            : const VunaFlowLogo(size: 30, showWordmark: true),
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
                isLabelVisible: _unreadNotifications > 0 || overdueLoans.isNotEmpty,
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
          if (MediaQuery.sizeOf(context).width < 840) const LogoutButton(),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isWideDesktop = width >= 960;
          final isMediumScreen = width >= 640 && width < 960;

          return RefreshIndicator(
            onRefresh: _loadData,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1360),
                      child: ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWideDesktop ? 28 : (isMediumScreen ? 20 : 16),
                          vertical: isWideDesktop ? 20 : 12,
                        ),
                        children: [
                          if (isWideDesktop) ...[
                            // ---------------------------------------------------
                            // Wide Desktop: Balanced 2-Column Responsive Layout
                            // ---------------------------------------------------
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column (flex: 62): Carousel, Overdue Alert, Quick Actions & Recent Apps
                                Expanded(
                                  flex: 62,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildHeroSection(loanInfos, totalDisbursed, totalPaid, totalRequested, overdueLoans, isDark),
                                      if (overdueLoans.isNotEmpty) ...[
                                        const SizedBox(height: 14),
                                        _buildOverdueAlertBanner(overdueLoans, isDark),
                                      ],
                                      const SizedBox(height: 16),
                                      // Quick Actions Grid
                                      _buildQuickActionsRow(context, isDark, cardBg, borderCol, textTitle, textSub),
                                      const SizedBox(height: 24),

                                      // Recent Applications in Left Feed
                                      _buildRecentApplicationsSection(
                                        context: context,
                                        isDesktop: true,
                                        isDark: isDark,
                                        cardBg: cardBg,
                                        borderCol: borderCol,
                                        textTitle: textTitle,
                                        textSub: textSub,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),

                                // Right Column (flex: 38): Portfolio Stats, Active Repayments & Agriculture Insights
                                Expanded(
                                  flex: 38,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Portfolio Summary',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: textTitle,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildStatsRow(
                                        activeLoansCount: activeLoansCount,
                                        approvedLoansCount: approvedLoansCount,
                                        totalRequested: totalRequested,
                                        cardBg: cardBg,
                                        borderCol: borderCol,
                                        textSub: textSub,
                                        textTitle: textTitle,
                                      ),
                                      const SizedBox(height: 18),

                                      // Active Loan Repayments Tracker Card
                                      if (activeLoansList.isNotEmpty) ...[
                                        _buildActiveLoansTrackerCard(
                                          activeLoans: activeLoansList,
                                          isDark: isDark,
                                          cardBg: cardBg,
                                          borderCol: borderCol,
                                          textTitle: textTitle,
                                          textSub: textSub,
                                        ),
                                        const SizedBox(height: 18),
                                      ],

                                      // Agricultural Advisory Card with AI Assistant Action
                                      _buildFarmingTipsCard(isDark, cardBg, borderCol, textTitle, textSub),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            // ---------------------------------------------------
                            // Tablet & Mobile Stacked Layout
                            // ---------------------------------------------------
                            _buildHeroSection(loanInfos, totalDisbursed, totalPaid, totalRequested, overdueLoans, isDark),
                            if (overdueLoans.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              _buildOverdueAlertBanner(overdueLoans, isDark),
                            ],
                            const SizedBox(height: 16),
                            _buildQuickActionsRow(context, isDark, cardBg, borderCol, textTitle, textSub),
                            const SizedBox(height: 22),
                            Text('Portfolio Summary', style: GoogleFonts.publicSans(fontSize: 16, fontWeight: FontWeight.w700, color: textTitle)),
                            const SizedBox(height: 12),
                            _buildStatsRow(
                              activeLoansCount: activeLoansCount,
                              approvedLoansCount: approvedLoansCount,
                              totalRequested: totalRequested,
                              cardBg: cardBg,
                              borderCol: borderCol,
                              textSub: textSub,
                              textTitle: textTitle,
                            ),
                            const SizedBox(height: 22),
                            // Recent Applications
                            _buildRecentApplicationsSection(
                              context: context,
                              isDesktop: isMediumScreen,
                              isDark: isDark,
                              cardBg: cardBg,
                              borderCol: borderCol,
                              textTitle: textTitle,
                              textSub: textSub,
                            ),
                            const SizedBox(height: 20),
                            // Agricultural Advisory Card
                            _buildFarmingTipsCard(isDark, cardBg, borderCol, textTitle, textSub),
                          ],
                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildStatsRow({
    required int activeLoansCount,
    required int approvedLoansCount,
    required double totalRequested,
    required Color cardBg,
    required Color borderCol,
    required Color textSub,
    required Color textTitle,
  }) {
    return Row(
      children: [
        Expanded(
          child: _SummaryStatCard(
            cardBg: cardBg,
            borderCol: borderCol,
            textSub: textSub,
            valueWidget: Text(
              '$activeLoansCount',
              style: GoogleFonts.publicSans(fontSize: 22, fontWeight: FontWeight.w800, color: textTitle),
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
                Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981))),
                const SizedBox(width: 5),
                Text('$approvedLoansCount', style: GoogleFonts.publicSans(fontSize: 22, fontWeight: FontWeight.w800, color: textTitle)),
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
                Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF59E0B))),
                const SizedBox(width: 4),
                Text(fmtCompact(totalRequested), style: GoogleFonts.publicSans(fontSize: 19, fontWeight: FontWeight.w800, color: textTitle)),
              ],
            ),
            label: 'Total Req.',
          ),
        ),
      ],
    );
  }

  Widget _buildRecentApplicationsSection({
    required BuildContext context,
    required bool isDesktop,
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    required Color textTitle,
    required Color textSub,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              onTap: () {
                if (widget.onNavigateToTab != null) {
                  widget.onNavigateToTab!(1);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoanTrackingScreen()),
                  ).then((_) => _loadData());
                }
              },
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
              child: Column(
                children: [
                  const Icon(Icons.spa_outlined, size: 36, color: Color(0xFF10B981)),
                  const SizedBox(height: 10),
                  Text(
                    'No loan applications yet.',
                    style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 15, color: textTitle),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Apply for a quick farming loan to grow your harvest.',
                    style: GoogleFonts.publicSans(color: textSub, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoanApplicationScreen()),
                    ).then((_) => _loadData()),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Apply For Loan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF133826),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (isDesktop)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 16,
              mainAxisExtent: 88,
            ),
            itemCount: _loans.take(6).length,
            itemBuilder: (context, i) {
              final loan = _loans[i];
              final statusInfo = _getLoanStatusInfo(loan as Map<String, dynamic>, isDark);
              return _RecentLoanCard(
                loan: loan,
                statusInfo: statusInfo,
                inGrid: true,
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
            },
          )
        else
          ..._loans.take(4).map((loan) {
            final statusInfo = _getLoanStatusInfo(loan as Map<String, dynamic>, isDark);
            return _RecentLoanCard(
              loan: loan,
              statusInfo: statusInfo,
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
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Active Loans Quick Tracker Widget (for Right Column)
  // ---------------------------------------------------------------------------
  Widget _buildActiveLoansTrackerCard({
    required List<dynamic> activeLoans,
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    required Color textTitle,
    required Color textSub,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Repayments',
                style: GoogleFonts.publicSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: textTitle),
              ),
              Text(
                '${activeLoans.length} active',
                style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...activeLoans.take(2).map((l) {
            final loan = l as Map<String, dynamic>;
            final reqAmt = double.tryParse(loan['amount_requested']?.toString() ?? '0') ?? 0.0;
            final pdAmt = double.tryParse(loan['amount_paid']?.toString() ?? '0') ?? 0.0;
            final pct = reqAmt > 0 ? (pdAmt / reqAmt).clamp(0.0, 1.0) : 0.0;
            final purpose = loan['purpose'] as String? ?? 'Agricultural Loan';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(purpose, style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w600, color: textTitle)),
                      Text('${(pct * 100).toStringAsFixed(0)}%', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: isDark ? const Color(0xFF1E3A2B) : const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Paid: ${fmtKsh(pdAmt)}', style: GoogleFonts.publicSans(fontSize: 11.5, color: textSub)),
                      Text('Goal: ${fmtKsh(reqAmt)}', style: GoogleFonts.publicSans(fontSize: 11.5, color: textSub)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Quick Actions Row
  // ---------------------------------------------------------------------------
  Widget _buildQuickActionsRow(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color borderCol,
    Color textTitle,
    Color textSub,
  ) {
    final actions = [
      (
        icon: Icons.add_circle_outline_rounded,
        label: 'Apply Loan',
        color: const Color(0xFF10B981),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoanApplicationScreen())).then((_) => _loadData()),
      ),
      (
        icon: Icons.payments_outlined,
        label: 'Repay Loan',
        color: const Color(0xFF0284C7),
        onTap: () {
          if (widget.onNavigateToTab != null) {
            widget.onNavigateToTab!(1);
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LoanTrackingScreen())).then((_) => _loadData());
          }
        },
      ),
      (
        icon: Icons.chat_bubble_outline_rounded,
        label: 'AI Assistant',
        color: const Color(0xFF8B5CF6),
        onTap: () {
          if (widget.onNavigateToTab != null) {
            widget.onNavigateToTab!(2);
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantScreen()));
          }
        },
      ),
    ];

    return Row(
      children: actions.map((act) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderCol),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: act.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(act.icon, size: 18, color: act.color),
                      const SizedBox(width: 8),
                      Text(
                        act.label,
                        style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w700, color: textTitle),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Farming Advisory Card with Interactive "Ask AI" button
  // ---------------------------------------------------------------------------
  Widget _buildFarmingTipsCard(
    bool isDark,
    Color cardBg,
    Color borderCol,
    Color textTitle,
    Color textSub,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14241B) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF223C2D) : const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A3826) : const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wb_sunny_outlined, color: Color(0xFF16A34A), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agricultural Advisory',
                      style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w800, color: textTitle),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Timely repayments unlock higher financing tiers for your farm inputs, fertilizers, and seed purchases.',
                      style: GoogleFonts.publicSans(fontSize: 12, color: textSub, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                if (widget.onNavigateToTab != null) {
                  widget.onNavigateToTab!(2);
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantScreen()));
                }
              },
              icon: const Icon(Icons.auto_awesome, size: 15, color: Color(0xFF10B981)),
              label: Text(
                'Ask AI Assistant',
                style: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Hero Carousel Section (Portfolio + Individual Loans)
  // ---------------------------------------------------------------------------
  Widget _buildHeroSection(
    List<Map<String, dynamic>> loans,
    double totalDisbursed,
    double totalPaid,
    double totalRequested,
    List<Map<String, dynamic>> overdueLoans,
    bool isDark,
  ) {
    if (loans.isEmpty) {
      return _buildSingleHeroCard(
        title: 'LOAN STATUS',
        statusChipText: 'READY TO APPLY',
        statusChipBg: isDark ? const Color(0xFF163E27) : const Color(0xFFD4EDDA),
        statusChipFg: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF155724),
        percentText: '0% Active',
        mainAmount: 'KSh 0',
        subText: 'Apply today for instant agricultural financing',
        progress: 0.0,
        progressColor: const Color(0xFF2ECC71),
        cardBg: isDark ? const Color(0xFF10261A) : const Color(0xFF133826),
        borderColor: isDark ? const Color(0xFF1E4833) : null,
        isDark: isDark,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoanApplicationScreen())).then((_) => _loadData()),
      );
    }

    // Build the list of cards:
    // Card 0: Portfolio Overview (if multiple loans)
    // Card 1..N: Each individual loan
    final List<Widget> cards = [];

    if (loans.length > 1) {
      final double overallProgress = totalDisbursed > 0 ? (totalPaid / totalDisbursed).clamp(0.0, 1.0) : (totalRequested > 0 ? (totalPaid / totalRequested).clamp(0.0, 1.0) : 0.0);
      final bool allFullyRepaid = totalPaid >= totalDisbursed && totalDisbursed > 0;
      final bool hasOverdue = overdueLoans.isNotEmpty;

      cards.add(
        _buildSingleHeroCard(
          title: 'PORTFOLIO OVERVIEW (${loans.length} LOANS)',
          statusChipText: hasOverdue
              ? '🚨 ${overdueLoans.length} OVERDUE'
              : (allFullyRepaid ? '✓ ALL REPAID' : '${(overallProgress * 100).toInt()}% REPAID'),
          statusChipBg: hasOverdue
              ? (isDark ? const Color(0xFF3B1616) : const Color(0xFFFEE2E2))
              : (isDark ? const Color(0xFF163E27) : const Color(0xFFD4EDDA)),
          statusChipFg: hasOverdue
              ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
              : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF155724)),
          percentText: '${(overallProgress * 100).toInt()}% Total Paid',
          mainAmount: fmtKsh(totalPaid),
          subText: 'Repaid of ${fmtKsh(totalDisbursed > 0 ? totalDisbursed : totalRequested)} Total Active Portfolio',
          progress: overallProgress,
          progressColor: hasOverdue ? const Color(0xFFEF4444) : const Color(0xFF2ECC71),
          cardBg: hasOverdue
              ? (isDark ? const Color(0xFF2A1212) : const Color(0xFF5A1515))
              : (isDark ? const Color(0xFF10261A) : const Color(0xFF133826)),
          borderColor: hasOverdue ? const Color(0xFF7F1D1D) : (isDark ? const Color(0xFF1E4833) : null),
          isDark: isDark,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoanTrackingScreen())).then((_) => _loadData()),
        ),
      );
    }

    // Individual loan cards
    for (int i = 0; i < loans.length; i++) {
      final loan = loans[i];
      final statusInfo = _getLoanStatusInfo(loan, isDark);
      final purpose = loan['purpose'] as String? ?? 'Agricultural Loan';

      Color cardColor;
      Color? cardBorder;
      Color barColor;

      if (statusInfo.isOverdue) {
        cardColor = isDark ? const Color(0xFF2E1212) : const Color(0xFF6B1A1A);
        cardBorder = const Color(0xFF991B1B);
        barColor = const Color(0xFFEF4444);
      } else if (statusInfo.isFullyRepaid) {
        cardColor = isDark ? const Color(0xFF10261A) : const Color(0xFF133826);
        cardBorder = isDark ? const Color(0xFF1E4833) : null;
        barColor = const Color(0xFF2ECC71);
      } else if (statusInfo.isInProgress) {
        cardColor = isDark ? const Color(0xFF0F2620) : const Color(0xFF124335);
        cardBorder = isDark ? const Color(0xFF1E4E40) : null;
        barColor = const Color(0xFF38BDF8);
      } else {
        cardColor = isDark ? const Color(0xFF16232E) : const Color(0xFF1E3A5F);
        cardBorder = isDark ? const Color(0xFF243B4E) : null;
        barColor = const Color(0xFFFBBF24);
      }

      cards.add(
        _buildSingleHeroCard(
          title: 'LOAN #${i + 1} · ${purpose.toUpperCase()}',
          statusChipText: statusInfo.statusChipText,
          statusChipBg: statusInfo.chipBg,
          statusChipFg: statusInfo.chipFg,
          percentText: '${(statusInfo.progress * 100).toInt()}% Completed',
          mainAmount: fmtKsh(statusInfo.reqAmt),
          subText: statusInfo.isFullyRepaid
              ? 'Fully Repaid of ${fmtKsh(statusInfo.reqAmt)} Total Loan'
              : '${fmtKsh(statusInfo.pdAmt)} Paid of ${fmtKsh(statusInfo.reqAmt)} Total Loan',
          progress: statusInfo.progress,
          progressColor: barColor,
          cardBg: cardColor,
          borderColor: cardBorder,
          isDark: isDark,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loan['id'])),
          ).then((_) => _loadData()),
        ),
      );
    }

    if (cards.length == 1) {
      return cards.first;
    }

    return Column(
      children: [
        SizedBox(
          height: 196,
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentCardIndex = i),
            children: cards,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(cards.length, (i) {
            final isSelected = _currentCardIndex == i;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isSelected ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected ? (isDark ? const Color(0xFF34D399) : const Color(0xFF133826)) : (isDark ? const Color(0xFF223C2D) : const Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSingleHeroCard({
    required String title,
    required String statusChipText,
    required Color statusChipBg,
    required Color statusChipFg,
    required String percentText,
    required String mainAmount,
    required String subText,
    required double progress,
    required Color progressColor,
    required Color cardBg,
    required Color? borderColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: cardBg.withValues(alpha: isDark ? 0.3 : 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusChipBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusChipText,
                        style: GoogleFonts.publicSans(
                          color: statusChipFg,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          percentText,
                          style: GoogleFonts.publicSans(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 16, color: Colors.white.withValues(alpha: 0.6)),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.publicSans(
                        color: const Color(0xFFB5D5C5).withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mainAmount,
                      style: GoogleFonts.publicSans(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.publicSans(
                        color: const Color(0xFFB5D5C5),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.black.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Overdue Alert Banner
  // ---------------------------------------------------------------------------
  Widget _buildOverdueAlertBanner(List<Map<String, dynamic>> overdueLoans, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF331414) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFEF4444)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF4A1A1A) : const Color(0xFFFECACA),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Action Required: Payment Overdue',
                  style: GoogleFonts.publicSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${overdueLoans.length} loan(s) past agreed repayment period. Tap to avoid penalty.',
                  style: GoogleFonts.publicSans(
                    fontSize: 12,
                    color: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: overdueLoans.first['id'])),
              ).then((_) => _loadData());
            },
            child: Text(
              'Pay Now',
              style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper for computing loan repayment & overdue status
  // ---------------------------------------------------------------------------
  _LoanStatusModel _getLoanStatusInfo(Map<String, dynamic> loan, bool isDark) {
    final status = loan['status'] as String? ?? 'submitted';
    final reqAmt = double.tryParse(loan['amount_requested']?.toString() ?? '0') ?? 0.0;
    final pdAmt = double.tryParse(loan['amount_paid']?.toString() ?? '0') ?? 0.0;
    final remAmt = (reqAmt - pdAmt).clamp(0.0, double.infinity);
    final progress = reqAmt > 0 ? (pdAmt / reqAmt).clamp(0.0, 1.0) : 0.0;
    final isFullyRepaid = (status == 'disbursed' || status == 'approved') && remAmt <= 0 && pdAmt > 0;

    bool isOverdue = false;
    int daysOverdue = 0;
    if (status == 'disbursed' && remAmt > 0) {
      final createdAt = DateTime.tryParse(loan['created_at'] ?? '');
      final months = int.tryParse(loan['repayment_period_months']?.toString() ?? '12') ?? 12;
      if (createdAt != null) {
        final dueDate = DateTime(createdAt.year, createdAt.month + months, createdAt.day);
        if (DateTime.now().isAfter(dueDate)) {
          isOverdue = true;
          daysOverdue = DateTime.now().difference(dueDate).inDays;
        }
      }
    }

    final isInProgress = status == 'disbursed' && !isFullyRepaid && !isOverdue;

    String statusChipText;
    Color chipBg;
    Color chipFg;
    IconData icon;
    Color iconBg;
    Color iconFg;

    if (isOverdue) {
      statusChipText = daysOverdue > 0 ? 'OVERDUE ($daysOverdue d)' : 'OVERDUE';
      chipBg = isDark ? const Color(0xFF3B1616) : const Color(0xFFFEE2E2);
      chipFg = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
      icon = Icons.warning_amber_rounded;
      iconBg = isDark ? const Color(0xFF381414) : const Color(0xFFFEE2E2);
      iconFg = const Color(0xFFEF4444);
    } else if (isFullyRepaid) {
      statusChipText = 'FULLY REPAID';
      chipBg = isDark ? const Color(0xFF163E27) : const Color(0xFFD4EDDA);
      chipFg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF155724);
      icon = Icons.check_circle_outline_rounded;
      iconBg = isDark ? const Color(0xFF163E27) : const Color(0xFFE8F5E9);
      iconFg = const Color(0xFF10B981);
    } else if (isInProgress) {
      statusChipText = 'IN PROGRESS';
      chipBg = isDark ? const Color(0xFF162D3E) : const Color(0xFFE0F2FE);
      chipFg = isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1);
      icon = Icons.hourglass_top_rounded;
      iconBg = isDark ? const Color(0xFF162D3E) : const Color(0xFFE0F2FE);
      iconFg = const Color(0xFF0284C7);
    } else if (status == 'approved') {
      statusChipText = 'APPROVED';
      chipBg = isDark ? const Color(0xFF163E27) : const Color(0xFFE8F5E9);
      chipFg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534);
      icon = Icons.verified_outlined;
      iconBg = isDark ? const Color(0xFF163E27) : const Color(0xFFE8F5E9);
      iconFg = const Color(0xFF10B981);
    } else if (status == 'rejected') {
      statusChipText = 'REJECTED';
      chipBg = isDark ? const Color(0xFF3B1616) : const Color(0xFFFDE8E8);
      chipFg = isDark ? const Color(0xFFFCA5A5) : const Color(0xFF9B1C1C);
      icon = Icons.cancel_outlined;
      iconBg = isDark ? const Color(0xFF3B1616) : const Color(0xFFFDE8E8);
      iconFg = const Color(0xFFEF4444);
    } else {
      statusChipText = statusLabel(status).toUpperCase();
      chipBg = isDark ? const Color(0xFF382D16) : const Color(0xFFFEF3C7);
      chipFg = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
      icon = Icons.pending_actions_rounded;
      iconBg = isDark ? const Color(0xFF382D16) : const Color(0xFFFEF3C7);
      iconFg = const Color(0xFFD97706);
    }

    return _LoanStatusModel(
      isOverdue: isOverdue,
      isFullyRepaid: isFullyRepaid,
      isInProgress: isInProgress,
      daysOverdue: daysOverdue,
      reqAmt: reqAmt,
      pdAmt: pdAmt,
      remAmt: remAmt,
      progress: progress,
      statusChipText: statusChipText,
      chipBg: chipBg,
      chipFg: chipFg,
      icon: icon,
      iconBg: iconBg,
      iconFg: iconFg,
    );
  }
}

class _LoanStatusModel {
  final bool isOverdue;
  final bool isFullyRepaid;
  final bool isInProgress;
  final int daysOverdue;
  final double reqAmt;
  final double pdAmt;
  final double remAmt;
  final double progress;
  final String statusChipText;
  final Color chipBg;
  final Color chipFg;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;

  _LoanStatusModel({
    required this.isOverdue,
    required this.isFullyRepaid,
    required this.isInProgress,
    required this.daysOverdue,
    required this.reqAmt,
    required this.pdAmt,
    required this.remAmt,
    required this.progress,
    required this.statusChipText,
    required this.chipBg,
    required this.chipFg,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
  });
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
  final _LoanStatusModel statusInfo;
  final bool inGrid;
  final VoidCallback onTap;
  final Color cardBg;
  final Color borderCol;
  final Color textTitle;
  final Color textSub;
  final bool isDark;

  const _RecentLoanCard({
    required this.loan,
    required this.statusInfo,
    this.inGrid = false,
    required this.onTap,
    required this.cardBg,
    required this.borderCol,
    required this.textTitle,
    required this.textSub,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(loan['amount_requested']?.toString() ?? '0') ?? 0.0;
    final purpose = loan['purpose'] as String? ?? 'Agricultural Loan';

    return Container(
      margin: inGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: statusInfo.isOverdue
            ? (isDark ? const Color(0xFF241212) : const Color(0xFFFFF5F5))
            : cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusInfo.isOverdue
              ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5))
              : borderCol,
          width: statusInfo.isOverdue ? 1.5 : 1.0,
        ),
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
                // Status-Specific Distinct Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusInfo.iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      statusInfo.icon,
                      size: 22,
                      color: statusInfo.iconFg,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            fmtKsh(amount),
                            style: GoogleFonts.publicSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textTitle,
                            ),
                          ),
                          if (statusInfo.isOverdue) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'OVERDUE',
                                style: GoogleFonts.publicSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        statusInfo.isFullyRepaid
                            ? '$purpose · Fully Repaid'
                            : (statusInfo.isInProgress
                                ? '$purpose · ${fmtKsh(statusInfo.pdAmt)} Paid'
                                : purpose),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.publicSans(
                          fontSize: 12.5,
                          color: statusInfo.isOverdue ? const Color(0xFFEF4444) : textSub,
                          fontWeight: statusInfo.isOverdue ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: statusInfo.chipBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusInfo.statusChipText,
                    style: GoogleFonts.publicSans(
                      color: statusInfo.chipFg,
                      fontSize: 11,
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
