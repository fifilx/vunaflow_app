import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/theme_toggle_button.dart';
import 'dart:async';
import 'repayment_flow_widget.dart';
import 'document_upload_screen.dart';

class LoanDetailScreen extends StatefulWidget {
  final String loanId;
  const LoanDetailScreen({super.key, required this.loanId});

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  List<dynamic> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/api/loans/${widget.loanId}');
      final paymentsRes = await ApiService.get('/api/loans/${widget.loanId}/payments');
      setState(() {
        _data = res;
        _payments = paymentsRes is List ? paymentsRes : [];
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showRepaymentModal(BuildContext context, double requestedAmount, double amountPaid) {
    final remaining = (requestedAmount - amountPaid).clamp(0, double.infinity);
    final amountCtrl = TextEditingController(text: remaining > 0 ? remaining.toStringAsFixed(0) : '10000');
    final phoneCtrl = TextEditingController(text: '0712345678');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return RepaymentFlowWidget(
          loanId: widget.loanId,
          initialAmount: amountCtrl.text,
          initialPhone: phoneCtrl.text,
          onSuccess: () {
            _load();
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C1610) : const Color(0xFFF9F8F5);
    final cardBg = isDark ? const Color(0xFF14241B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF223C2D) : const Color(0xFFE5E7EB);
    final dividerCol = isDark ? const Color(0xFF223C2D) : const Color(0xFFF3F4F6);
    final textTitle = isDark ? const Color(0xFFF4F6F0) : const Color(0xFF1F2937);
    final textSub = isDark ? const Color(0xFF9EBAA9) : const Color(0xFF6B7280);
    final titleCol = isDark ? const Color(0xFFF4F6F0) : const Color(0xFF133826);
    final primaryBtnCol = isDark ? const Color(0xFF34D399) : const Color(0xFF133826);

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text('Loan Details', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w700, color: titleCol)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_data == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text('Loan Details', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w700, color: titleCol)),
        ),
        body: Center(child: Text('Could not load this application.', style: TextStyle(color: textSub))),
      );
    }

    final loan = _data!['loan'];
    final history = _data!['history'] as List<dynamic>;
    final status = loan['status'] as String;

    final double requestedAmt = double.tryParse(loan['amount_requested'].toString()) ?? 0.0;
    final double paidAmt = double.tryParse((loan['amount_paid'] ?? 0).toString()) ?? 0.0;
    final double remainingAmt = (requestedAmt - paidAmt).clamp(0, double.infinity);
    final double progress = requestedAmt > 0 ? (paidAmt / requestedAmt).clamp(0.0, 1.0) : 0.0;

    final formattedSubmittedOn = loan['created_at'] != null
        ? DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(loan['created_at']))
        : 'Aug 7, 2026 9:34 AM';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: Container(
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
        ),
        title: Text(
          'Loan Details',
          style: GoogleFonts.fraunces(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: titleCol,
          ),
        ),
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          children: [
            // Header Amount & Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'APPLICATION ID: ${loan['id'].toString().substring(0, loan['id'].toString().length > 10 ? 10 : loan['id'].toString().length)}...',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF8BA596) : const Color(0xFF9CA3AF),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        fmtKsh(requestedAmt),
                        style: GoogleFonts.publicSans(
                          fontSize: 24,
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
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Repayment Tracker Card
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
                      Text(
                        'Repayment Tracker',
                        style: GoogleFonts.publicSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2ECC71).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(progress * 100).toStringAsFixed(1)}% Paid',
                          style: GoogleFonts.publicSans(
                            color: const Color(0xFF2ECC71),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amount Paid',
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              color: const Color(0xFFB5D5C5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            fmtKsh(paidAmt),
                            style: GoogleFonts.publicSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Remaining Balance',
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              color: const Color(0xFFB5D5C5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            fmtKsh(remainingAmt),
                            style: GoogleFonts.publicSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (remainingAmt <= 0)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2519),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2ECC71).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, color: Color(0xFF2ECC71), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Loan Fully Repaid',
                            style: GoogleFonts.publicSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2ECC71),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => _showRepaymentModal(context, requestedAmt, paidAmt),
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: Text(
                        'Make Repayment (M-Pesa)',
                        style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.shamba900,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Details Information List Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Purpose',
                    labelColor: textSub,
                    valueWidget: Text(
                      loan['purpose'] ?? 'General farming',
                      style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w600, color: textTitle),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Divider(color: dividerCol, height: 22, thickness: 1),
                  _DetailRow(
                    label: 'Repayment Period',
                    labelColor: textSub,
                    valueWidget: Text(
                      '${loan['repayment_period_months'] ?? 12} months',
                      style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w600, color: textTitle),
                    ),
                  ),
                  Divider(color: dividerCol, height: 22, thickness: 1),
                  _DetailRow(
                    label: 'Branch',
                    labelColor: textSub,
                    valueWidget: Text(
                      loan['branch_name'] ?? 'Head Office',
                      style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w600, color: textTitle),
                    ),
                  ),
                  Divider(color: dividerCol, height: 22, thickness: 1),
                  _DetailRow(
                    label: 'Submitted On',
                    labelColor: textSub,
                    valueWidget: Text(
                      formattedSubmittedOn,
                      style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: textTitle),
                    ),
                  ),
                  Divider(color: dividerCol, height: 22, thickness: 1),
                  _DetailRow(
                    label: 'Eligibility Indication',
                    labelColor: textSub,
                    valueWidget: Text(
                      loan['eligibility_result'] ?? 'Likely eligible',
                      style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Manage Documents Outlined Button
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DocumentUploadScreen(loanId: loan['id'])),
              ),
              icon: const Icon(Icons.article_outlined, size: 18),
              label: Text(
                'Manage Documents',
                style: GoogleFonts.publicSans(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryBtnCol,
                side: BorderSide(color: primaryBtnCol, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 24),

            // Past Payments Receipt Log (if any)
            if (_payments.isNotEmpty) ...[
              Text(
                'Payment Receipts',
                style: GoogleFonts.publicSans(fontSize: 16, fontWeight: FontWeight.w700, color: textTitle),
              ),
              const SizedBox(height: 10),
              ..._payments.map((p) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderCol),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fmtKsh(double.parse(p['amount'].toString())),
                                  style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 14, color: textTitle),
                                ),
                                Text(
                                  '${p['payment_method']} • Ref: ${p['transaction_ref']}',
                                  style: GoogleFonts.ibmPlexMono(fontSize: 11, color: textSub),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          DateFormat.yMMMd().format(DateTime.parse(p['created_at'])),
                          style: GoogleFonts.publicSans(fontSize: 12, color: textSub),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 18),
            ],

            // Status Timeline History
            Text(
              'Status History',
              style: GoogleFonts.publicSans(fontSize: 16, fontWeight: FontWeight.w700, color: textTitle),
            ),
            const SizedBox(height: 12),
            ...history.reversed.map((h) => _TimelineEntry(entry: h, textTitle: textTitle, textSub: textSub, borderCol: borderCol)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final Widget valueWidget;
  final Color labelColor;

  const _DetailRow({
    required this.label,
    required this.valueWidget,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.publicSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(child: valueWidget),
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final Map<String, dynamic> entry;
  final Color textTitle;
  final Color textSub;
  final Color borderCol;

  const _TimelineEntry({
    required this.entry,
    required this.textTitle,
    required this.textSub,
    required this.borderCol,
  });

  @override
  Widget build(BuildContext context) {
    final status = entry['status'] as String;
    final color = AppColors.statusColors[status] ?? AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              Container(width: 2, height: 28, color: borderCol),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusLabel(status), style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 13.5, color: textTitle)),
                Text(
                  DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(entry['created_at'])),
                  style: GoogleFonts.publicSans(fontSize: 12, color: textSub),
                ),
                if (entry['comment'] != null)
                  Text(entry['comment'], style: GoogleFonts.publicSans(fontSize: 12.5, color: textTitle)),
                if (entry['changed_by_name'] != null)
                  Text('by ${entry['changed_by_name']}', style: GoogleFonts.publicSans(fontSize: 12, fontStyle: FontStyle.italic, color: textSub)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
