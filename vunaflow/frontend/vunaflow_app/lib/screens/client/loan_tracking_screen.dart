import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/logout_button.dart';
import 'loan_detail_screen.dart';
import 'loan_application_screen.dart';

/// Shows every loan application belonging to the client, with its current
/// status. When [embedded] is true this is used as a bottom-nav tab (no
/// back arrow); otherwise it can be pushed as a standalone screen.
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Loan Applications'),
        automaticallyImplyLeading: !widget.embedded,
        actions: const [LogoutButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LoanApplicationScreen()))
            .then((_) => _load()),
        icon: const Icon(Icons.add),
        label: const Text('New Loan'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _loans.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(40),
                      children: const [
                        Center(
                            child: Icon(Icons.receipt_long_outlined,
                                size: 56, color: AppColors.textSecondary)),
                        SizedBox(height: 12),
                        Center(child: Text('No loan applications yet.')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _loans.length,
                      itemBuilder: (context, i) {
                        final loan = _loans[i];
                        return _LoanCard(
                          loan: loan,
                          onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          LoanDetailScreen(loanId: loan['id'])))
                              .then((_) => _load()),
                        );
                      },
                    ),
            ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final Map<String, dynamic> loan;
  final VoidCallback onTap;
  const _LoanCard({required this.loan, required this.onTap});

  static const _stages = [
    'submitted',
    'under_review',
    'documents_verified',
    'approved',
    'disbursed'
  ];

  @override
  Widget build(BuildContext context) {
    final status = loan['status'] as String;
    final color = AppColors.statusColors[status] ?? AppColors.textSecondary;
    final isRejected = status == 'rejected';
    final currentStageIndex = _stages.indexOf(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                        'KSh ${double.parse(loan['amount_requested'].toString()).toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(statusLabel(status),
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(loan['purpose'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 14),
              if (!isRejected)
                Row(
                  children: List.generate(_stages.length, (i) {
                    final reached = currentStageIndex >= i;
                    return Expanded(
                      child: Container(
                        height: 5,
                        margin: EdgeInsets.only(
                            right: i == _stages.length - 1 ? 0 : 4),
                        decoration: BoxDecoration(
                          color: reached ? AppColors.primary : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                )
              else
                const Row(
                  children: [
                    Icon(Icons.cancel_outlined,
                        size: 16, color: AppColors.danger),
                    SizedBox(width: 6),
                    Text('Application was not approved',
                        style:
                            TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
