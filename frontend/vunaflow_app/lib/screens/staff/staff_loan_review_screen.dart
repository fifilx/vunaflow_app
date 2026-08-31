import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
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
    final appBarBg = isDark ? const Color(0xFF0F1B14) : AppColors.shamba900;
    final scaffoldBg = isDark ? const Color(0xFF0C1610) : AppColors.parchment2;

    if (loan == null) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          title: const Text('Review Application'),
          actions: const [ThemeToggleButton()],
        ),
        body: const Center(child: Text('Loan application not found')),
      );
    }

    final currentStatus = loan['status'] as String? ?? 'submitted';
    final amount = double.tryParse(loan['amount_requested'].toString()) ?? 0;
    final clientName = loan['client_name'] as String? ?? 'Applicant';

    final isMobile = MediaQuery.of(context).size.width < 860;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        foregroundColor: AppColors.parchment,
        title: Row(
          children: [
            const Icon(Icons.spa_outlined, color: AppColors.goldPale, size: 22),
            const SizedBox(width: 10),
            Text(
              'VunaFlow · Staff',
              style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.parchment),
            ),
          ],
        ),
        actions: const [ThemeToggleButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, size: 16, color: AppColors.inkSoft),
                      const SizedBox(width: 8),
                      Text(
                        'Review application',
                        style: GoogleFonts.publicSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // Review Hero Header
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.shamba800, AppColors.shamba900],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clientName,
                            style: GoogleFonts.fraunces(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              color: AppColors.parchment,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            fmtKsh(amount),
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 22,
                              color: AppColors.goldPale,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      _buildHeaderStatusBadge(currentStatus),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Review Content Columns
                isMobile
                    ? Column(
                        children: [
                          _buildLeftColumn(loan, documents, history),
                          const SizedBox(height: 24),
                          _buildRightColumn(currentStatus),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 13, child: _buildLeftColumn(loan, documents, history)),
                          const SizedBox(width: 28),
                          Expanded(flex: 9, child: _buildRightColumn(currentStatus)),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x2ED6A23D),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0x66D6A23D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 16, color: AppColors.goldPale),
          const SizedBox(width: 6),
          Text(
            statusLabel(status),
            style: GoogleFonts.publicSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.goldPale,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(Map<String, dynamic> loan, List<dynamic> documents, List<dynamic> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Purpose & Details Card
        _buildCard(
          title: 'PURPOSE',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loan['purpose'] as String? ?? 'N/A',
                style: GoogleFonts.publicSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailLine('Repayment period', '${loan['repayment_period_months']} months'),
              _buildDetailLine('Amount Repaid (Client)', fmtKsh(double.tryParse((loan['amount_paid'] ?? 0).toString()) ?? 0)),
              _buildAccountNumberRow(loan),
              _buildDetailLine('Branch', loan['branch_name'] as String? ?? 'N/A'),
              _buildDetailLine(
                'Eligibility indication',
                loan['eligibility_result'] as String? ?? 'Likely eligible',
                isEligibility: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Repayment & Overdue Tracking Card for Disbursed / Active Loans
        Builder(builder: (context) {
          final status = loan['status'] as String? ?? '';
          final reqAmt = double.tryParse(loan['amount_requested']?.toString() ?? '0') ?? 0.0;
          final pdAmt = double.tryParse((loan['amount_paid'] ?? 0).toString()) ?? 0.0;
          final remaining = (reqAmt - pdAmt).clamp(0, double.infinity);
          final pctRem = reqAmt > 0 ? ((remaining / reqAmt) * 100) : 0.0;

          final createdAt = DateTime.tryParse(loan['created_at'] ?? '');
          final months = int.tryParse(loan['repayment_period_months']?.toString() ?? '12') ?? 12;
          bool isOverdue = false;
          int daysOverdue = 0;
          if (status == 'disbursed' && createdAt != null && remaining > 0) {
            final dueDate = DateTime(createdAt.year, createdAt.month + months, createdAt.day);
            if (DateTime.now().isAfter(dueDate)) {
              isOverdue = true;
              daysOverdue = DateTime.now().difference(dueDate).inDays;
            }
          }

          return _buildCard(
            title: 'REPAYMENT & OVERDUE MONITORING',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isOverdue) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDEDEC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EXCEEDED REPAYMENT PERIOD',
                                style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.red),
                              ),
                              Text(
                                'This loan has passed the agreed $months-month period by $daysOverdue days. Remaining balance is ${fmtKsh(remaining)} (${pctRem.toStringAsFixed(1)}% due).',
                                style: GoogleFonts.publicSans(fontSize: 12.5, color: const Color(0xFF78281F)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Repayment Progress', style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('${pctRem.toStringAsFixed(1)}% Remaining', style: GoogleFonts.ibmPlexMono(fontWeight: FontWeight.w700, fontSize: 13, color: isOverdue ? Colors.red : AppColors.shamba700)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: reqAmt > 0 ? (pdAmt / reqAmt).clamp(0.0, 1.0) : 0.0,
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                    color: isOverdue ? Colors.red : AppColors.shamba700,
                  ),
                ),
                const SizedBox(height: 14),
                _buildDetailLine('Total Loan Amount', fmtKsh(reqAmt)),
                _buildDetailLine('Amount Paid by Farmer', fmtKsh(pdAmt)),
                _buildDetailLine('Remaining Balance Due', fmtKsh(remaining)),

                if (_payments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Payment Receipt Trail (${_payments.length})', style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 14)),
                  if (loan['account_number'] != null && loan['account_number'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Text('Deposited to Account: ${loan['account_number']}', style: GoogleFonts.publicSans(fontSize: 12, color: AppColors.shamba700, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 8),
                   ..._payments.map((p) {
                        final isReversable = p['status'] == 'completed';
                        final isReversed = p['status'] == 'reversed';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isReversed ? Colors.red.withValues(alpha: 0.04) : AppColors.parchment2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isReversed ? Colors.red.withValues(alpha: 0.2) : AppColors.line),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fmtKsh(double.parse(p['amount'].toString())),
                                    style: GoogleFonts.publicSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      decoration: isReversed ? TextDecoration.lineThrough : null,
                                      color: isReversed ? Colors.grey : AppColors.ink,
                                    ),
                                  ),
                                  Text(
                                    '${p['payment_method']} • Ref: ${p['transaction_ref']}',
                                    style: GoogleFonts.ibmPlexMono(fontSize: 11.5, color: AppColors.inkSoft),
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
                              Row(
                                children: [
                                  Text(
                                    DateFormat.yMMMd().format(DateTime.parse(p['created_at'])),
                                    style: GoogleFonts.publicSans(fontSize: 12, color: AppColors.inkFaint),
                                  ),
                                  if (isReversable) ...[
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () => _reversePayment(p),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text('Reverse', style: GoogleFonts.publicSans(fontSize: 11, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      })
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: 22),
        // Documents Card
        _buildCard(
          title: 'DOCUMENTS',
          child: documents.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line, style: BorderStyle.solid),
                  ),
                  child: Center(
                    child: Text(
                      'No documents uploaded yet.',
                      style: GoogleFonts.publicSans(fontSize: 14, color: AppColors.inkFaint),
                    ),
                  ),
                )
              : Column(
                  children: documents.map((doc) {
                    final filePath = doc['file_path'] as String?;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.line)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.file_present_outlined, color: AppColors.shamba700, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                _docTypeLabel(doc['doc_type']),
                                style: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (filePath != null)
                            TextButton(
                              onPressed: () => _openDocument(filePath),
                              child: const Text('View file'),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 22),
        // History Card
        _buildCard(
          title: 'HISTORY',
          child: history.isEmpty
              ? Text('No history entries', style: GoogleFonts.publicSans(color: AppColors.inkFaint))
              : Column(
                  children: history.map((item) {
                    final status = item['status'] as String? ?? '';
                    final comment = item['comment'] as String?;
                    final dateStr = item['created_at'] != null
                        ? DateFormat('MMM dd, yyyy · h:mm a').format(DateTime.parse(item['created_at']).toLocal())
                        : '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: status == 'approved' ? AppColors.shamba700 : AppColors.sky,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.publicSans(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                    children: [
                                      TextSpan(text: statusLabel(status)),
                                      TextSpan(
                                        text: ' — $dateStr',
                                        style: GoogleFonts.ibmPlexMono(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: AppColors.inkFaint,
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
                                        fontSize: 13.5,
                                        color: AppColors.inkSoft,
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

  Widget _buildRightColumn(String currentStatus) {
    final currentIdx = _stages.indexWhere((s) => s.$1 == currentStatus);

    return _buildCard(
      title: 'CHANGE STATUS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 5 Stage Track
          Column(
            children: List.generate(_stages.length, (idx) {
              final stage = _stages[idx];
              final isDone = currentIdx != -1 && idx < currentIdx;
              final isCurrent = currentIdx == idx;

              Color borderClr = AppColors.line;
              Color bgClr = AppColors.parchment2;
              Color fgClr = AppColors.inkFaint;

              if (isDone) {
                borderClr = AppColors.shamba700;
                bgClr = AppColors.shamba700;
                fgClr = Colors.white;
              } else if (isCurrent) {
                borderClr = AppColors.gold;
                bgClr = AppColors.gold;
                fgClr = AppColors.ink;
              }

              return InkWell(
                onTap: _updating ? null : () => _updateStatus(stage.$1),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: bgClr,
                          border: Border.all(color: borderClr, width: 2),
                        ),
                        child: Icon(stage.$3, size: 20, color: fgClr),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        stage.$2,
                        style: GoogleFonts.publicSans(
                          fontSize: 14,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                          color: isCurrent ? AppColors.ink : (isDone ? AppColors.shamba700 : AppColors.inkFaint),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          // Reject button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.brick, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Mark as not eligible',
                      style: GoogleFonts.publicSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
                OutlinedButton(
                  onPressed: _updating ? null : () => _updateStatus('rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brick,
                    side: const BorderSide(color: AppColors.brick, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: const Text('Reject'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(34, 36, 30, 0.04),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color.fromRGBO(34, 36, 30, 0.06),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.publicSans(
              fontSize: 13,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: AppColors.inkFaint,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailLine(String label, String value, {bool isEligibility = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.publicSans(fontSize: 14, color: AppColors.inkSoft),
          ),
          if (isEligibility)
            Row(
              children: [
                const Icon(Icons.check, size: 15, color: AppColors.shamba700),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: GoogleFonts.publicSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.shamba700,
                  ),
                ),
              ],
            )
          else
            Text(
              value,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAccountNumberRow(Map<String, dynamic> loan) {
    final accNum = loan['account_number']?.toString() ?? '';
    final status = loan['status'] as String? ?? '';
    final canEdit = !['rejected'].contains(status);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Account Number',
            style: GoogleFonts.publicSans(fontSize: 14, color: AppColors.inkSoft),
          ),
          Row(
            children: [
              Text(
                accNum.isNotEmpty ? accNum : 'Not assigned',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: accNum.isNotEmpty ? AppColors.ink : AppColors.brick,
                ),
              ),
              if (canEdit) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _updateAccountNumber(accNum),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(Icons.edit, size: 16, color: AppColors.shamba700),
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          currentAccNum.isEmpty ? 'Assign Account Number' : 'Edit Account Number',
          style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.ink),
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
            child: Text('Cancel', style: GoogleFonts.publicSans(color: AppColors.inkSoft)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.ink,
            ),
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm M-Pesa Reversal',
          style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.brick),
        ),
        content: Text(
          'Are you sure you want to reverse the repayment of ${fmtKsh(double.parse(payment['amount'].toString()))} (Ref: ${payment['transaction_ref']})?\n\nThis will send a reversal request to Safaricom Sandbox and deduct the amount from the client\'s paid balance.',
          style: GoogleFonts.publicSans(fontSize: 14, color: AppColors.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.publicSans(color: AppColors.inkSoft)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brick,
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
