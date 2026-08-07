import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
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
    if (_loading) {
      return Scaffold(appBar: AppBar(title: const Text('Loan Details')), body: const Center(child: CircularProgressIndicator()));
    }
    if (_data == null) {
      return Scaffold(appBar: AppBar(title: const Text('Loan Details')), body: const Center(child: Text('Could not load this application.')));
    }

    final loan = _data!['loan'];
    final history = _data!['history'] as List<dynamic>;
    final status = loan['status'] as String;
    final color = AppColors.statusColors[status] ?? AppColors.textSecondary;

    final double requestedAmt = double.tryParse(loan['amount_requested'].toString()) ?? 0.0;
    final double paidAmt = double.tryParse((loan['amount_paid'] ?? 0).toString()) ?? 0.0;
    final double remainingAmt = (requestedAmt - paidAmt).clamp(0, double.infinity);
    final double progress = requestedAmt > 0 ? (paidAmt / requestedAmt).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Loan Details')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Status & Overview Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'KSh ${requestedAmt.toStringAsFixed(0)}',
                        style: GoogleFonts.fraunces(fontSize: 26, fontWeight: FontWeight.w700),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                        child: Text(statusLabel(status), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Application ID: ${loan['id'].toString().substring(0, 8)}...', style: GoogleFonts.ibmPlexMono(fontSize: 12, color: Colors.grey[700])),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Repayment Progress Widget (Visible for Disbursed or Approved Loans)
            if (status == 'disbursed' || status == 'approved') ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF122318),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Loan Repayment Tracker', style: GoogleFonts.fraunces(fontSize: 18, color: AppColors.parchment, fontWeight: FontWeight.w700)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${(progress * 100).toStringAsFixed(1)}% Paid', style: GoogleFonts.publicSans(color: AppColors.goldPale, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        backgroundColor: const Color(0xFF1E3B29),
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AMOUNT PAID', style: GoogleFonts.ibmPlexMono(fontSize: 11, color: AppColors.goldPale)),
                            const SizedBox(height: 2),
                            Text('KSh ${paidAmt.toStringAsFixed(0)}', style: GoogleFonts.publicSans(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('REMAINING BALANCE', style: GoogleFonts.ibmPlexMono(fontSize: 11, color: Colors.redAccent)),
                            const SizedBox(height: 2),
                            Text('KSh ${remainingAmt.toStringAsFixed(0)}', style: GoogleFonts.publicSans(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (remainingAmt > 0)
                      ElevatedButton.icon(
                        onPressed: () => _showRepaymentModal(context, requestedAmt, paidAmt),
                        icon: const Icon(Icons.payments_outlined, size: 20),
                        label: Text('Make Repayment (M-Pesa)', style: GoogleFonts.publicSans(fontSize: 15, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.shamba900,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Loan Fully Repaid',
                              style: GoogleFonts.publicSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.greenAccent),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            _InfoRow(label: 'Purpose', value: loan['purpose'] ?? '-'),
            if (loan['account_number'] != null && loan['account_number'].toString().isNotEmpty)
              _InfoRow(label: 'Account Number', value: loan['account_number'].toString()),
            _InfoRow(label: 'Repayment Period', value: '${loan['repayment_period_months']} months'),
            _InfoRow(label: 'Branch', value: loan['branch_name'] ?? 'Not set'),
            _InfoRow(label: 'Submitted On', value: DateFormat.yMMMd().add_jm().format(DateTime.parse(loan['created_at']))),
            if (loan['eligibility_result'] != null) _InfoRow(label: 'Eligibility Indication', value: loan['eligibility_result']),
            const SizedBox(height: 20),

            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentUploadScreen(loanId: loan['id']))),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Manage Documents'),
            ),
            const SizedBox(height: 28),

            // Past Payments Receipt Log
            if (_payments.isNotEmpty) ...[
              Text('Payment Receipts', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ..._payments.map((p) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF122318).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.shamba700, size: 22),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('KSh ${double.parse(p['amount'].toString()).toStringAsFixed(0)}', style: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 15)),
                                Text('${p['payment_method']} • Ref: ${p['transaction_ref']}', style: GoogleFonts.ibmPlexMono(fontSize: 12, color: Colors.grey[700])),
                              ],
                            ),
                          ],
                        ),
                        Text(DateFormat.yMMMd().format(DateTime.parse(p['created_at'])), style: GoogleFonts.publicSans(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  )),
              const SizedBox(height: 24),
            ],

            Text('Status History', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...history.reversed.map((h) => _TimelineEntry(entry: h)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _TimelineEntry({required this.entry});

  @override
  Widget build(BuildContext context) {
    final status = entry['status'] as String;
    final color = AppColors.statusColors[status] ?? AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              Container(width: 2, height: 30, color: AppColors.border),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusLabel(status), style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(DateFormat.yMMMd().add_jm().format(DateTime.parse(entry['created_at'])), style: Theme.of(context).textTheme.bodyMedium),
                if (entry['comment'] != null) Text(entry['comment'], style: Theme.of(context).textTheme.bodyMedium),
                if (entry['changed_by_name'] != null)
                  Text('by ${entry['changed_by_name']}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
