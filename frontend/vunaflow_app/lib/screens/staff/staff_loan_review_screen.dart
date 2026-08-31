import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/repayment_milestone_tracker.dart';
import '../../widgets/theme_toggle_button.dart';

class StaffLoanReviewScreen extends StatefulWidget {
  final String loanId;
  const StaffLoanReviewScreen({super.key, required this.loanId});

  @override
  State<StaffLoanReviewScreen> createState() => _StaffLoanReviewScreenState();
}

class _StaffLoanReviewScreenState extends State<StaffLoanReviewScreen> {
  bool _loading = true;
  bool _updating = false;
  Map<String, dynamic>? _data;

  final _stages = const [
    ('submitted', 'Submitted', Icons.assignment_outlined),
    ('under_review', 'Under review', Icons.manage_search_outlined),
    ('documents_verified', 'Docs verified', Icons.file_present_outlined),
    ('approved', 'Approved', Icons.check_circle_outline),
    ('disbursed', 'Disbursed', Icons.payments_outlined),
  ];

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
      final payRes = await ApiService.get('/api/loans/${widget.loanId}/payments');
      setState(() {
        _data = res;
        _payments = payRes is List ? payRes : [];
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    final commentCtrl = TextEditingController();
    final accountCtrl = TextEditingController();
    final label = _stages.firstWhere((s) => s.$1 == status, orElse: () => ('', status, Icons.info)).$2;
    final bool requiresAccount = status == 'approved';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Set status to "$label"?',
          style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(
                hintText: 'Add an optional note or comment for the client...',
              ),
              maxLines: 2,
            ),
            if (requiresAccount) const SizedBox(height: 16),
            if (requiresAccount)
              TextField(
                controller: accountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Account Number',
                  hintText: 'e.g., VUNA-123456',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.publicSans(color: AppColors.inkSoft)),
          ),
          ElevatedButton(
            onPressed: () {
              if (requiresAccount && accountCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account number is required for approval.')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.ink,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _updating = true);
    try {
      final body = {
        'status': status,
        'comment': commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
      };
      if (requiresAccount) {
        body['account_number'] = accountCtrl.text.trim();
      }

      await ApiService.patch('/api/loans/${widget.loanId}/status', body: body);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application status updated successfully')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  String _docTypeLabel(String? docType) {
    switch (docType) {
      case 'national_id':
        return 'National ID';
      case 'title_deed':
        return 'Title Deed';
      case 'collateral':
        return 'Collateral Document';
      default:
        return 'Other Document';
    }
  }

  Future<void> _openDocument(String filePath) async {
    final uri = Uri.parse(ApiConfig.fileUrl(filePath));
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this document')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.parchment2,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final loan = _data?['loan'] as Map<String, dynamic>?;
    final history = (_data?['history'] as List<dynamic>?) ?? [];
    final documents = (_data?['documents'] as List<dynamic>?) ?? [];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDark ? const Color(0xFF0F1B14) : const Color(0xFF133826);
    final scaffoldBg = isDark ? const Color(0xFF0C1610) : const Color(0xFFF9F8F5);
    final cardBg = isDark ? const Color(0xFF14241B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF223C2D) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? const Color(0xFFF4F6F0) : const Color(0xFF1F2937);
    final textMuted = isDark ? const Color(0xFF9EBAA9) : const Color(0xFF6B7280);

    if (loan == null) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: appBarBg,
          foregroundColor: Colors.white,
          title: const Text('Review Application'),
          actions: const [ThemeToggleButton()],
        ),
        body: const Center(child: Text('Loan application not found')),
      );
    }

    final currentStatus = loan['status'] as String? ?? 'submitted';
    final amount = double.tryParse(loan['amount_requested']?.toString() ?? '0') ?? 0.0;
    final clientName = loan['client_name'] as String? ?? 'Applicant';

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 840;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.spa_outlined, color: Color(0xFFD4AF37), size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Review Application',
                style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 28 : 16,
              vertical: isDesktop ? 24 : 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, size: 16, color: textMuted),
                        const SizedBox(width: 6),
                        Text(
                          'Back to applications',
                          style: GoogleFonts.publicSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Review Hero Header (Responsive Card)
                Container(
                  padding: EdgeInsets.all(isDesktop ? 24 : 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3B29), Color(0xFF122318)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, heroConstraints) {
                      final isNarrowHero = heroConstraints.maxWidth < 480;

                      if (isNarrowHero) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clientName,
                              style: GoogleFonts.fraunces(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              fmtKsh(amount),
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 20,
                                color: const Color(0xFFF1DDAF),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildHeaderStatusBadge(loan, isDark),
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  clientName,
                                  style: GoogleFonts.fraunces(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  fmtKsh(amount),
                                  style: GoogleFonts.ibmPlexMono(
                                    fontSize: 20,
                                    color: const Color(0xFFF1DDAF),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildHeaderStatusBadge(loan, isDark),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Review Content (2-Column Desktop, 1-Column Mobile)
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 13,
                        child: _buildLeftColumn(loan, documents, history, isDark, cardBg, cardBorder, textPrimary, textMuted),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 9,
                        child: _buildRightColumn(currentStatus, isDark, cardBg, cardBorder, textPrimary, textMuted),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildLeftColumn(loan, documents, history, isDark, cardBg, cardBorder, textPrimary, textMuted),
                      const SizedBox(height: 18),
                      _buildRightColumn(currentStatus, isDark, cardBg, cardBorder, textPrimary, textMuted),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildHeaderStatusBadge(Map<String, dynamic> loan, bool isDark) {
    final statusInfo = getDetailedLoanStatus(loan);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: statusInfo.badgeBg(isDark),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        statusInfo.fullTitle,
        style: GoogleFonts.publicSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: statusInfo.badgeFg(isDark),
        ),
      ),
    );
  }

  Widget _buildLeftColumn(
    Map<String, dynamic> loan,
    List<dynamic> documents,
    List<dynamic> history,
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textMuted,
  ) {
    final statusInfo = getDetailedLoanStatus(loan);
    final reqAmt = double.tryParse(loan['amount_requested']?.toString() ?? '0') ?? 0.0;
    final pdAmt = double.tryParse(loan['amount_paid']?.toString() ?? '0') ?? 0.0;
    final remaining = (reqAmt - pdAmt).clamp(0.0, double.infinity);
    final months = int.tryParse(loan['repayment_period_months']?.toString() ?? '12') ?? 12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Purpose & Details Card
        _buildCard(
          title: 'LOAN DETAILS & APPLICANT',
          cardBg: cardBg,
          cardBorder: cardBorder,
          textPrimary: textPrimary,
          textMuted: textMuted,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loan['purpose'] as String? ?? 'N/A',
                style: GoogleFonts.publicSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _buildDetailLine('Repayment period', '$months months', cardBorder, textMuted, textPrimary),
              _buildDetailLine('Amount Paid (Client)', fmtKsh(pdAmt), cardBorder, textMuted, textPrimary),
              _buildAccountNumberRow(loan, cardBorder, textMuted, textPrimary, isDark),
              _buildDetailLine('Branch', loan['branch_name'] as String? ?? 'Head Office', cardBorder, textMuted, textPrimary),
              _buildDetailLine(
                'Eligibility indication',
                loan['eligibility_result'] as String? ?? 'Likely eligible',
                cardBorder,
                textMuted,
                textPrimary,
                isEligibility: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Repayment & Overdue Monitoring Card with 5-Segment Milestone Tracker
        _buildCard(
          title: 'REPAYMENT & MILESTONES',
          cardBg: cardBg,
          cardBorder: cardBorder,
          textPrimary: textPrimary,
          textMuted: textMuted,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (statusInfo.isOverdue) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A1414) : const Color(0xFFFDEDEC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EXCEEDED REPAYMENT PERIOD',
                              style: GoogleFonts.publicSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'This loan has passed its $months-month schedule. Remaining balance due: ${fmtKsh(remaining)}.',
                              style: GoogleFonts.publicSans(
                                fontSize: 12,
                                color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF78281F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 5-Segment Milestone Tracker
              RepaymentMilestoneTracker(
                requestedAmount: reqAmt,
                paidAmount: pdAmt,
                isOverdue: statusInfo.isOverdue,
                isDark: isDark,
              ),
              const SizedBox(height: 14),

              _buildDetailLine('Total Loan Amount', fmtKsh(reqAmt), cardBorder, textMuted, textPrimary),
              _buildDetailLine('Amount Paid by Farmer', fmtKsh(pdAmt), cardBorder, textMuted, textPrimary),
              _buildDetailLine('Remaining Balance Due', fmtKsh(remaining), cardBorder, textMuted, textPrimary),

              if (_payments.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Payment Receipt Trail (${_payments.length})',
                  style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 14, color: textPrimary),
                ),
                if (loan['account_number'] != null && loan['account_number'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 6),
                    child: Text(
                      'Account: ${loan['account_number']}',
                      style: GoogleFonts.publicSans(fontSize: 12, color: const Color(0xFF16A34A), fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 8),
                ..._payments.map((p) {
                  final isReversable = p['status'] == 'completed';
                  final isReversed = p['status'] == 'reversed';
                  final pAmt = double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0;
                  final pDate = DateTime.tryParse(p['created_at']?.toString() ?? '');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isReversed
                          ? (isDark ? const Color(0xFF2A1414) : const Color(0xFFFFF0F0))
                          : (isDark ? const Color(0xFF101E16) : const Color(0xFFF9FAFB)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isReversed
                            ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5))
                            : cardBorder,
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, pConstraints) {
                        final isNarrow = pConstraints.maxWidth < 360;

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    fmtKsh(pAmt),
                                    style: GoogleFonts.publicSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      decoration: isReversed ? TextDecoration.lineThrough : null,
                                      color: isReversed ? Colors.grey : textPrimary,
                                    ),
                                  ),
                                  if (pDate != null)
                                    Text(
                                      DateFormat.yMMMd().format(pDate),
                                      style: GoogleFonts.publicSans(fontSize: 11, color: textMuted),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${p['payment_method']} · Ref: ${p['transaction_ref']}',
                                      style: GoogleFonts.ibmPlexMono(fontSize: 11, color: textMuted),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isReversable)
                                    TextButton(
                                      onPressed: () => _reversePayment(p),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('Reverse', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                    ),
                                ],
                              ),
                            ],
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fmtKsh(pAmt),
                                    style: GoogleFonts.publicSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      decoration: isReversed ? TextDecoration.lineThrough : null,
                                      color: isReversed ? Colors.grey : textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${p['payment_method']} • Ref: ${p['transaction_ref']}',
                                    style: GoogleFonts.ibmPlexMono(fontSize: 11.5, color: textMuted),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (isReversed)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Reversed',
                                        style: GoogleFonts.publicSans(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (pDate != null)
                                  Text(
                                    DateFormat.yMMMd().format(pDate),
                                    style: GoogleFonts.publicSans(fontSize: 11.5, color: textMuted),
                                  ),
                                if (isReversable) ...[
                                  const SizedBox(height: 2),
                                  TextButton(
                                    onPressed: () => _reversePayment(p),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Reverse', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Documents Card
        _buildCard(
          title: 'DOCUMENTS',
          cardBg: cardBg,
          cardBorder: cardBorder,
          textPrimary: textPrimary,
          textMuted: textMuted,
          child: documents.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Center(
                    child: Text(
                      'No documents uploaded yet.',
                      style: GoogleFonts.publicSans(fontSize: 13.5, color: textMuted),
                    ),
                  ),
                )
              : Column(
                  children: documents.map((doc) {
                    final filePath = doc['file_path'] as String?;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: cardBorder)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.file_present_outlined, color: Color(0xFF16A34A), size: 20),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _docTypeLabel(doc['doc_type']),
                                    style: GoogleFonts.publicSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (filePath != null)
                            TextButton(
                              onPressed: () => _openDocument(filePath),
                              child: const Text('View file', style: TextStyle(fontSize: 13)),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 18),

        // History Card
        _buildCard(
          title: 'TIMELINE & HISTORY',
          cardBg: cardBg,
          cardBorder: cardBorder,
          textPrimary: textPrimary,
          textMuted: textMuted,
          child: history.isEmpty
              ? Text('No history entries', style: GoogleFonts.publicSans(color: textMuted))
              : Column(
                  children: history.map((item) {
                    final status = item['status'] as String? ?? '';
                    final comment = item['comment'] as String?;
                    final dateStr = item['created_at'] != null
                        ? DateFormat('MMM dd, yyyy · h:mm a').format(DateTime.parse(item['created_at']).toLocal())
                        : '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: status == 'approved' ? const Color(0xFF16A34A) : const Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.publicSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                    children: [
                                      TextSpan(text: statusLabel(status)),
                                      TextSpan(
                                        text: ' — $dateStr',
                                        style: GoogleFonts.ibmPlexMono(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w400,
                                          color: textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (comment != null && comment.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      comment,
                                      style: GoogleFonts.publicSans(
                                        fontSize: 13,
                                        color: textMuted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildRightColumn(
    String currentStatus,
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textMuted,
  ) {
    final currentIdx = _stages.indexWhere((s) => s.$1 == currentStatus);

    return _buildCard(
      title: 'CHANGE STATUS',
      cardBg: cardBg,
      cardBorder: cardBorder,
      textPrimary: textPrimary,
      textMuted: textMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 5 Stage Track
          Column(
            children: List.generate(_stages.length, (idx) {
              final stage = _stages[idx];
              final isDone = currentIdx != -1 && idx < currentIdx;
              final isCurrent = currentIdx == idx;

              Color borderClr = cardBorder;
              Color bgClr = isDark ? const Color(0xFF101E16) : const Color(0xFFF9FAFB);
              Color fgClr = textMuted;

              if (isDone) {
                borderClr = const Color(0xFF16A34A);
                bgClr = const Color(0xFF16A34A);
                fgClr = Colors.white;
              } else if (isCurrent) {
                borderClr = const Color(0xFFD4AF37);
                bgClr = const Color(0xFFD4AF37);
                fgClr = const Color(0xFF1F2937);
              }

              return InkWell(
                onTap: _updating ? null : () => _updateStatus(stage.$1),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: bgClr,
                          border: Border.all(color: borderClr, width: 2),
                        ),
                        child: Icon(stage.$3, size: 18, color: fgClr),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          stage.$2,
                          style: GoogleFonts.publicSans(
                            fontSize: 13.5,
                            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                            color: isCurrent
                                ? textPrimary
                                : (isDone ? const Color(0xFF16A34A) : textMuted),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          // Reject button
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Mark as not eligible',
                          style: GoogleFonts.publicSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _updating ? null : () => _updateStatus('rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Reject', style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required Widget child,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.publicSans(
              fontSize: 12,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailLine(
    String label,
    String value,
    Color cardBorder,
    Color textMuted,
    Color textPrimary, {
    bool isEligibility = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cardBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 6,
            child: Text(
              label,
              style: GoogleFonts.publicSans(fontSize: 13.5, color: textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 5,
            child: isEligibility
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(Icons.check, size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          value,
                          style: GoogleFonts.publicSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF16A34A),
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  )
                : Text(
                    value,
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountNumberRow(
    Map<String, dynamic> loan,
    Color cardBorder,
    Color textMuted,
    Color textPrimary,
    bool isDark,
  ) {
    final accNum = loan['account_number']?.toString() ?? '';
    final status = loan['status'] as String? ?? '';
    final canEdit = !['rejected'].contains(status);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cardBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'Account Number',
              style: GoogleFonts.publicSans(fontSize: 13.5, color: textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                accNum.isNotEmpty ? accNum : 'Not assigned',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: accNum.isNotEmpty ? textPrimary : const Color(0xFFDC2626),
                ),
              ),
              if (canEdit) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _updateAccountNumber(accNum),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.edit, size: 15, color: Color(0xFF16A34A)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateAccountNumber(String currentAccNum) async {
    final accountCtrl = TextEditingController(text: currentAccNum);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          currentAccNum.isEmpty ? 'Assign Account Number' : 'Edit Account Number',
          style: GoogleFonts.fraunces(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: accountCtrl,
          decoration: const InputDecoration(
            labelText: 'Account Number',
            hintText: 'e.g., VUNA-123456',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (accountCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account number cannot be empty.')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _updating = true);
    try {
      await ApiService.patch('/api/loans/${widget.loanId}/account_number', body: {
        'account_number': accountCtrl.text.trim(),
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account number updated successfully')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _reversePayment(Map<String, dynamic> payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm M-Pesa Reversal',
          style: GoogleFonts.fraunces(fontSize: 19, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626)),
        ),
        content: Text(
          'Are you sure you want to reverse the repayment of ${fmtKsh(double.parse(payment['amount'].toString()))} (Ref: ${payment['transaction_ref']})?\n\nThis will send a reversal request to Safaricom Sandbox and deduct the amount from the client\'s paid balance.',
          style: GoogleFonts.publicSans(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Reversal'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _updating = true);
    try {
      await ApiService.post('/api/loans/${widget.loanId}/payments/${payment['id']}/reverse');
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reversal initiated successfully')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }
}
