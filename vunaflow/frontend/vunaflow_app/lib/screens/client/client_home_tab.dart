import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/logout_button.dart';
import 'notifications_screen.dart';
import 'loan_detail_screen.dart';

class ClientHomeTab extends StatefulWidget {
  const ClientHomeTab({super.key});

  @override
  State<ClientHomeTab> createState() => _ClientHomeTabState();
}

class _ClientHomeTabState extends State<ClientHomeTab> {
  bool _loading = true;
  List<dynamic> _loans = [];
  int _unreadNotifications = 0;
  double _overpaymentBalance = 0.0;

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
        ApiService.get('/api/profile'),
      ]);
      setState(() {
        _loans = results[0] as List<dynamic>;
        _unreadNotifications = (results[1] as Map<String, dynamic>)['unread_count'] ?? 0;
        final profile = (results[2] as Map<String, dynamic>)['farmer_profile'];
        _overpaymentBalance = double.tryParse((profile?['overpayment_balance'] ?? 0).toString()) ?? 0.0;
      });
    } catch (_) {
      // Keep dashboard usable even if a widget's data fails to load.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _transferOverpaymentToLoan() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Transfer Credit to Active Loan'),
        content: Text(
          'Transfer KSh ${_overpaymentBalance.toStringAsFixed(2)} from your Overpayment Credit balance directly to reduce your active loan balance?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.shamba900),
            child: const Text('Confirm Transfer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await ApiService.post('/api/profile/overpayment/transfer');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Credit transferred successfully!'), backgroundColor: Colors.green),
      );
      _loadData();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not transfer credit. Please try again.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _requestRefund() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Request Overpayment Refund'),
        content: Text(
          'Submit a refund request for KSh ${_overpaymentBalance.toStringAsFixed(2)}? AFC Branch staff will process the payout to your M-Pesa account.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.shamba900),
            child: const Text('Request Refund'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await ApiService.post('/api/profile/overpayment/refund');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Refund request submitted!'), backgroundColor: Colors.green),
      );
      _loadData();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not submit refund request. Please try again.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final activeLoans = _loans.where((l) => !['rejected', 'disbursed'].contains(l['status'])).length;
    final approved = _loans.where((l) => l['status'] == 'approved' || l['status'] == 'disbursed').length;
    final totalRequested = _loans.fold<double>(0, (sum, l) => sum + double.parse(l['amount_requested'].toString()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('VunaFlow'),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('$_unreadNotifications'),
              isLabelVisible: _unreadNotifications > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())).then((_) => _loadData()),
          ),
          const LogoutButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Welcome
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back,', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
                        Text(user?.fullName ?? 'Farmer', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Text(
                          'Track your loans, manage your farm profile, and stay updated — all in one place.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ),
                  if (_overpaymentBalance > 0) ...[
                    const SizedBox(height: 18),
                    Builder(builder: (context) {
                      final hasUnpaidLoan = _loans.any((l) =>
                        (l['status'] == 'disbursed' || l['status'] == 'approved') &&
                        (double.tryParse((l['amount_paid'] ?? 0).toString()) ?? 0.0) <
                            (double.tryParse(l['amount_requested'].toString()) ?? 0.0),
                      );

                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F2D1E),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                          border: Border.all(color: const Color(0xFF2ECC71), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1E422C),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF2ECC71), size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Overpayment Credit Balance',
                                        style: GoogleFonts.publicSans(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'KSh ${_overpaymentBalance.toStringAsFixed(2)}',
                                        style: GoogleFonts.fraunces(color: const Color(0xFF2ECC71), fontSize: 22, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E422C),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF2ECC71).withValues(alpha: 0.6)),
                                  ),
                                  child: Text(
                                    'Refundable',
                                    style: GoogleFonts.publicSans(color: const Color(0xFF2ECC71), fontSize: 12, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Divider(color: Colors.white12, height: 1),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if (hasUnpaidLoan)
                                  ElevatedButton.icon(
                                    onPressed: _transferOverpaymentToLoan,
                                    icon: const Icon(Icons.sync_alt, size: 16),
                                    label: const Text('Transfer to Active Loan'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2ECC71),
                                      foregroundColor: const Color(0xFF0F2D1E),
                                      textStyle: GoogleFonts.publicSans(fontWeight: FontWeight.w800, fontSize: 12),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: _requestRefund,
                                  icon: const Icon(Icons.output, size: 16),
                                  label: const Text('Request Refund'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white38),
                                    textStyle: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  // Active Repayment Banner if farmer has an active/disbursed loan
                  if (_loans.any((l) => l['status'] == 'disbursed' || l['status'] == 'approved')) ...[
                    const SizedBox(height: 18),
                    Builder(builder: (context) {
                      final disbursedLoan = _loans.firstWhere(
                        (l) => l['status'] == 'disbursed' || l['status'] == 'approved',
                        orElse: () => _loans.first,
                      );
                      final reqAmt = double.tryParse(disbursedLoan['amount_requested'].toString()) ?? 0.0;
                      final pdAmt = double.tryParse((disbursedLoan['amount_paid'] ?? 0).toString()) ?? 0.0;
                      final remAmt = (reqAmt - pdAmt).clamp(0, double.infinity);
                      final pct = reqAmt > 0 ? (pdAmt / reqAmt).clamp(0.0, 1.0) : 0.0;

                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF122318),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.payments_outlined, color: AppColors.goldPale, size: 20),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Active Loan Repayment', style: GoogleFonts.fraunces(fontSize: 16, color: AppColors.parchment, fontWeight: FontWeight.w700)),
                                        if (disbursedLoan['account_number'] != null && disbursedLoan['account_number'].toString().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text('Account No: ${disbursedLoan['account_number']}', style: GoogleFonts.publicSans(color: AppColors.goldPale.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600)),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                remAmt <= 0
                                    ? Text('Fully Repaid', style: GoogleFonts.publicSans(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.w700))
                                    : Text('KSh ${remAmt.toStringAsFixed(0)} Due', style: GoogleFonts.publicSans(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 10,
                                backgroundColor: const Color(0xFF1E3B29),
                                color: AppColors.gold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('KSh ${pdAmt.toStringAsFixed(0)} Paid of KSh ${reqAmt.toStringAsFixed(0)}', style: GoogleFonts.publicSans(color: AppColors.goldPale, fontSize: 12)),
                                if (remAmt <= 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                                    child: Text('Fully Repaid', style: GoogleFonts.publicSans(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: disbursedLoan['id'])),
                                      ).then((_) => _loadData());
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.gold,
                                      foregroundColor: AppColors.shamba900,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                    child: Text('Pay Loan (M-Pesa)', style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.w800)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                  ],

                  // Loan summary
                  Text('Loan Summary', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _StatCard(label: 'Active', value: '$activeLoans', color: AppColors.info)),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(label: 'Approved', value: '$approved', color: AppColors.success)),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(label: 'Total Requested', value: 'KSh ${totalRequested ~/ 1000}K', color: AppColors.accentDark)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Loan status
                  Text('Recent Applications', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (_loans.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                      child: const Center(child: Text('You have no loan applications yet. Tap "New Loan" to get started.')),
                    )
                  else
                    ..._loans.take(3).map((loan) => _LoanTile(loan: loan, onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loan['id']))).then((_) => _loadData());
                        })),
                  const SizedBox(height: 80),
                ],
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _LoanTile extends StatelessWidget {
  final Map<String, dynamic> loan;
  final VoidCallback onTap;
  const _LoanTile({required this.loan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = loan['status'] as String;
    final color = AppColors.statusColors[status] ?? AppColors.textSecondary;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        title: Text('KSh ${double.parse(loan['amount_requested'].toString()).toStringAsFixed(0)}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loan['purpose'] ?? ''),
            if (loan['account_number'] != null && loan['account_number'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Acc: ${loan['account_number']}', style: GoogleFonts.publicSans(fontSize: 11.5, color: AppColors.shamba700, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(statusLabel(status), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
