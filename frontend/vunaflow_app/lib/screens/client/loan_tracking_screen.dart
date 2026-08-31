import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/logout_button.dart';
import '../../widgets/theme_toggle_button.dart';
import 'loan_detail_screen.dart';
import 'loan_application_screen.dart';

/// Shows every loan application belonging to the client, matching
/// the "My Applications" card and repayment segmented progress design.
class LoanTrackingScreen extends StatefulWidget {
  final bool embedded;
  const LoanTrackingScreen({super.key, this.embedded = false});

  @override
  State<LoanTrackingScreen> createState() => _LoanTrackingScreenState();
}

class _LoanTrackingScreenState extends State<LoanTrackingScreen> {
  bool _loading = true;
  List<dynamic> _loans = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/api/loans/mine');
      setState(() => _loans = res as List<dynamic>);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C1610) : const Color(0xFFF9F8F5);
    final borderCol = isDark ? const Color(0xFF223C2D) : const Color(0xFFE5E7EB);
    final titleCol = isDark ? const Color(0xFFF4F6F0) : const Color(0xFF133826);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: (canPop && !widget.embedded)
            ? Container(
                margin: const EdgeInsets.only(left: 14, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF162A1F) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderCol),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: isDark ? const Color(0xFFF4F6F0) : const Color(0xFF1F2937), size: 18),
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                ),
              )
            : null,
        title: Text(
          'My Applications',
          style: GoogleFonts.fraunces(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: titleCol,
          ),
        ),
        actions: const [
          ThemeToggleButton(),
          LogoutButton(),
        ],
      ),
      floatingActionButton: widget.embedded
          ? null
          : FloatingActionButton.extended(
              heroTag: 'loan_tracking_screen_fab',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoanApplicationScreen()),
              ).then((_) => _load()),
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
              label: const Text(
                'New Loan',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
              backgroundColor: isDark ? const Color(0xFF1A4630) : const Color(0xFF133826),
              elevation: 4,
              shape: const StadiumBorder(),
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isMultiColumn = width >= 640;
          final crossAxisCount = width >= 1100 ? 3 : (width >= 640 ? 2 : 1);

          return RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1360),
                      child: _loans.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(40),
                              children: [
                                Center(
                                  child: Icon(Icons.receipt_long_outlined, size: 56, color: isDark ? const Color(0xFF6B8A77) : const Color(0xFF9CA3AF)),
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    'No loan applications yet.',
                                    style: GoogleFonts.publicSans(color: isDark ? const Color(0xFF9EBAA9) : const Color(0xFF6B7280), fontSize: 14),
                                  ),
                                ),
                              ],
                            )
                          : isMultiColumn
                              ? GridView.builder(
                                  padding: EdgeInsets.fromLTRB(width >= 960 ? 28 : 16, 20, width >= 960 ? 28 : 16, 100),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    mainAxisExtent: 220,
                                  ),
                                  itemCount: _loans.length,
                                  itemBuilder: (context, i) {
                                    final loan = _loans[i];
                                    return _ApplicationCard(
                                      loan: loan,
                                      isDark: isDark,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loan['id'])),
                                      ).then((_) => _load()),
                                    );
                                  },
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                                  itemCount: _loans.length,
                                  itemBuilder: (context, i) {
                                    final loan = _loans[i];
                                    return _ApplicationCard(
                                      loan: loan,
                                      isDark: isDark,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loan['id'])),
                                      ).then((_) => _load()),
                                    );
                                  },
                                ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> loan;
  final bool isDark;
  final VoidCallback onTap;

  const _ApplicationCard({
    required this.loan,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = loan['status'] as String? ?? 'submitted';
    final reqAmt = double.tryParse(loan['amount_requested'].toString()) ?? 0.0;
    final pdAmt = double.tryParse((loan['amount_paid'] ?? 0).toString()) ?? 0.0;
    final purpose = loan['purpose'] as String? ?? 'General farming';

    final cardBg = isDark ? const Color(0xFF14241B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF223C2D) : const Color(0xFFE5E7EB);
    final textTitle = isDark ? const Color(0xFFF4F6F0) : const Color(0xFF1F2937);
    final textSub = isDark ? const Color(0xFF9EBAA9) : const Color(0xFF6B7280);
    final filledCol = isDark ? const Color(0xFF34D399) : const Color(0xFF133826);
    final unfilledCol = isDark ? const Color(0xFF223C2D) : const Color(0xFFE5E7EB);

    final double pct = reqAmt > 0 ? (pdAmt / reqAmt).clamp(0.0, 1.0) : 0.0;
    final bool isDisbursed = status == 'disbursed';
    final bool isFullyRepaid = (reqAmt - pdAmt) <= 0 && pdAmt > 0;

    // Segment calculation (5 segments)
    int filledSegments = 0;
    if (isFullyRepaid) {
      filledSegments = 5;
    } else if (isDisbursed && pdAmt > 0) {
      filledSegments = (pct * 5).round().clamp(1, 5);
    } else if (status == 'approved' || status == 'disbursed') {
      filledSegments = 5;
    }

    String trackerStatusText = 'Fully Repaid (100%)';
    if (isFullyRepaid) {
      trackerStatusText = 'Fully Repaid (100%)';
    } else if (pdAmt > 0) {
      trackerStatusText = '${(pct * 100).toInt()}% Paid';
    } else if (status == 'disbursed') {
      trackerStatusText = 'Fully Repaid (100%)';
    } else {
      trackerStatusText = statusLabel(status);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      fmtKsh(reqAmt),
                      style: GoogleFonts.publicSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textTitle,
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
                const SizedBox(height: 3),
                Text(
                  purpose,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.publicSans(
                    fontSize: 13,
                    color: textSub,
                  ),
                ),
                const SizedBox(height: 14),

                // Segmented Repayment Progress Bar (5 rounded pill dashes)
                Row(
                  children: List.generate(5, (index) {
                    final bool isFilled = index < filledSegments;
                    return Expanded(
                      child: Container(
                        height: 5,
                        margin: EdgeInsets.only(right: index == 4 ? 0 : 6),
                        decoration: BoxDecoration(
                          color: isFilled ? filledCol : unfilledCol,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),

                // Bottom tracker labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Repayment Tracker',
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textSub,
                      ),
                    ),
                    Text(
                      trackerStatusText,
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: filledCol,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

