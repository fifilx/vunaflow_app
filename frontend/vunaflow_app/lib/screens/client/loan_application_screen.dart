import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/logout_button.dart';
import 'document_upload_screen.dart';
import 'edit_profile_screen.dart';

/// Illustrative annual interest rate used only for the repayment estimate
/// shown to the farmer before they submit. AFC determines the actual
/// approved rate during review — this is clearly disclaimed in the UI.
const double _illustrativeAnnualRate = 0.12;

class LoanApplicationScreen extends StatefulWidget {
  const LoanApplicationScreen({super.key});

  @override
  State<LoanApplicationScreen> createState() => _LoanApplicationScreenState();
}

class _LoanApplicationScreenState extends State<LoanApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _periodCtrl = TextEditingController(text: '12');
  final _collateralCtrl = TextEditingController();

  bool _submitting = false;
  bool _checkingEligibility = false;
  Map<String, dynamic>? _eligibility;
  String? _error;

  List<dynamic> _branches = [];
  String? _selectedBranchId;
  bool _loadingBranches = true;

  // Profile-completeness gate: a farmer must have a complete profile
  // before they're allowed to apply for a loan at all.
  bool _checkingProfile = true;
  bool _profileComplete = false;
  List<String> _missingFields = [];

  @override
  void initState() {
    super.initState();
    _checkProfileThenLoadBranches();
  }

  Future<void> _checkProfileThenLoadBranches() async {
    setState(() => _checkingProfile = true);
    try {
      final profileRes = await ApiService.get('/api/profile');
      final farm = profileRes['farmer_profile'] ?? {};
      final missing = <String>[];
      if (farm['national_id'] == null ||
          farm['national_id'].toString().isEmpty) {
        missing.add('National ID');
      }
      if (farm['date_of_birth'] == null) missing.add('Date of Birth');
      final hasCrop = farm['primary_crop'] != null &&
          farm['primary_crop'].toString().isNotEmpty;
      final hasLivestock = farm['livestock_type'] != null &&
          farm['livestock_type'].toString().isNotEmpty;
      if (!hasCrop && !hasLivestock) missing.add('Crop or Livestock Type');

      setState(() {
        _missingFields = missing;
        _profileComplete = missing.isEmpty;
      });

      if (_profileComplete) {
        await _loadBranches();
      }
    } catch (_) {
      // If we can't verify, err on the side of letting the backend be the
      // final authority — it enforces the same rule server-side anyway.
      setState(() => _profileComplete = true);
      await _loadBranches();
    } finally {
      if (mounted) setState(() => _checkingProfile = false);
    }
  }

  Future<void> _goCompleteProfile() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    _checkProfileThenLoadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() => _loadingBranches = true);
    try {
      final branches = await ApiService.get('/api/branches');
      String? preselected;
      try {
        final profile = await ApiService.get('/api/profile');
        preselected = profile['account']?['branch_id'];
      } catch (_) {
        // Profile branch is a nice-to-have preselect; not fetching it isn't fatal.
      }
      setState(() {
        _branches = branches as List<dynamic>;
        _selectedBranchId = preselected;
      });
    } catch (_) {
      // Leave the dropdown empty; the retry button (built into the field) covers this.
    } finally {
      if (mounted) setState(() => _loadingBranches = false);
    }
  }

  Future<void> _checkEligibility() async {
    final amount = double.tryParse(_amountCtrl.text);
    setState(() => _checkingEligibility = true);
    try {
      final res = await ApiService.get('/api/loans/eligibility-check',
          query: {'amount': amount});
      setState(() => _eligibility = res);
    } catch (_) {
      // Non-blocking — eligibility is informational only.
    } finally {
      if (mounted) setState(() => _checkingEligibility = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final res = await ApiService.post('/api/loans', body: {
        'amount_requested': double.parse(_amountCtrl.text),
        'purpose': _purposeCtrl.text.trim(),
        'repayment_period_months': int.parse(_periodCtrl.text),
        'branch_id': _selectedBranchId,
        'collateral': _collateralCtrl.text.trim(),
      });
      if (!mounted) return;
      final loan = res['loan'];
      final serverMessage = res['message'] as String? ??
          'Your loan application has been submitted. Please visit any AFC branch for proper document verification.';

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Loan Submitted'),
          content: Text(serverMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DocumentUploadScreen(loanId: loan['id'])),
                );
              },
              child: const Text('Upload Documents Now'),
            ),
          ],
        ),
      );
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(
          () => _error = 'Could not submit application. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    _periodCtrl.dispose();
    _collateralCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingProfile) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('Loan Application'),
            actions: const [LogoutButton()]),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_profileComplete) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('Loan Application'),
            actions: const [LogoutButton()]),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.assignment_late_outlined,
                    size: 56, color: AppColors.warning),
                const SizedBox(height: 16),
                Text('Complete Your Profile First',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  'Before applying for a loan, please complete the following in your farmer profile:',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ..._missingFields.map((f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text('•  $f',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    )),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _goCompleteProfile,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Complete Profile'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
          title: const Text('Loan Application'),
          actions: const [LogoutButton()]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(_error!,
                      style: TextStyle(color: Colors.red.shade700)),
                ),
                const SizedBox(height: 16),
              ],
              Text('Requested Amount (KSh)',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    hintText: 'e.g. 250000', prefixText: 'KSh '),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final amount = double.tryParse(v ?? '');
                  if (amount == null) return 'Enter a valid amount';
                  if (amount < 100000) {
                    return 'Loan amount must be at least KSh 100,000';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text('Purpose of Loan',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _purposeCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: const [CapitalizeFirstLetterFormatter()],
                decoration: const InputDecoration(
                    hintText:
                        'e.g. Purchase of certified maize seed and fertilizer for 5 acres'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please describe the purpose of this loan'
                    : null,
              ),
              const SizedBox(height: 20),
              Text('Collateral description',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _collateralCtrl,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: const [CapitalizeFirstLetterFormatter()],
                decoration: const InputDecoration(
                    hintText:
                        'e.g. Land Title Deed No. 12345 or Toyota Logbook'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please describe the collateral offered'
                    : null,
              ),
              const SizedBox(height: 20),
              Text('AFC Branch', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (_loadingBranches)
                const LinearProgressIndicator()
              else if (_branches.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Could not load the branch list. Check your connection to the server.',
                          style: TextStyle(color: Colors.orange.shade800),
                        ),
                      ),
                      TextButton(
                          onPressed: _loadBranches, child: const Text('Retry')),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedBranchId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      hintText: 'Select the branch handling your loan',
                      prefixIcon: Icon(Icons.store_outlined)),
                  items: _branches
                      .map<DropdownMenuItem<String>>((b) => DropdownMenuItem(
                          value: b['id'] as String,
                          child:
                              Text(b['name'], overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedBranchId = v),
                  validator: (v) =>
                      v == null ? 'Please select an AFC branch' : null,
                ),
              const SizedBox(height: 20),
              Text('Repayment Period (months)',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _periodCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) {
                    return 'Enter a valid repayment period';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _RepaymentPreview(
                  amountText: _amountCtrl.text, periodText: _periodCtrl.text),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _checkingEligibility ? null : _checkEligibility,
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(
                    _checkingEligibility ? 'Checking...' : 'Check Eligibility'),
              ),
              if (_eligibility != null) ...[
                const SizedBox(height: 12),
                _EligibilityResultCard(eligibility: _eligibility!),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Application'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EligibilityResultCard extends StatelessWidget {
  final Map<String, dynamic> eligibility;
  const _EligibilityResultCard({required this.eligibility});

  @override
  Widget build(BuildContext context) {
    final likelyEligible = eligibility['result'] == 'Likely eligible';
    final color = likelyEligible ? AppColors.success : AppColors.warning;
    final reasons = (eligibility['reasons'] as List<dynamic>? ?? []);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(likelyEligible ? Icons.check_circle : Icons.info,
                  color: color),
              const SizedBox(width: 8),
              Text(eligibility['result'],
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...reasons.map((r) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $r',
                      style: Theme.of(context).textTheme.bodyMedium),
                )),
          ],
          const SizedBox(height: 4),
          Text(
            'This is an automated indication based on simple eligibility rules, not a final decision. AFC staff will review your full application.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

/// Shows an illustrative monthly-repayment breakdown (principal vs interest)
/// as a stacked bar chart, so a farmer can see roughly what repaying the
/// loan will look like before submitting. Uses a standard reducing-balance
/// amortization formula with a disclaimed illustrative rate — AFC determines
/// the actual approved rate during review.
class _RepaymentPreview extends StatelessWidget {
  final String amountText;
  final String periodText;
  const _RepaymentPreview({required this.amountText, required this.periodText});

  @override
  Widget build(BuildContext context) {
    final principal = double.tryParse(amountText);
    final months = int.tryParse(periodText);

    if (principal == null ||
        principal < 100000 ||
        months == null ||
        months <= 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            const Icon(Icons.show_chart, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Enter an amount and repayment period above to see an estimated repayment schedule.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    const monthlyRate = _illustrativeAnnualRate / 12;
    final factor = _powApprox(1 + monthlyRate, months);
    final monthlyPayment = monthlyRate == 0
        ? principal / months
        : principal * monthlyRate * factor / (factor - 1);

    double balance = principal;
    final schedule = <_ScheduleEntry>[];
    final monthsToShow = months > 12 ? 12 : months;
    for (int i = 1; i <= monthsToShow; i++) {
      final interest = balance * monthlyRate;
      final principalPortion = monthlyPayment - interest;
      balance -= principalPortion;
      schedule.add(_ScheduleEntry(
          month: i, interest: interest, principal: principalPortion));
    }

    final totalRepayment = monthlyPayment * months;
    final totalInterest = totalRepayment - principal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estimated Repayment Schedule',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'For illustration only, based on an indicative ${(_illustrativeAnnualRate * 100).toStringAsFixed(0)}% p.a. reducing-balance rate. '
            'Your actual rate and repayment terms are determined by AFC during review.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _statTile(context, 'Est. Monthly Payment',
                      'KSh ${monthlyPayment.toStringAsFixed(0)}')),
              const SizedBox(width: 12),
              Expanded(
                  child: _statTile(context, 'Est. Total Interest',
                      'KSh ${totalInterest.toStringAsFixed(0)}')),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: true, reservedSize: 40)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= schedule.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('${schedule[i].month}',
                                style: const TextStyle(fontSize: 10)));
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(schedule.length, (i) {
                  final e = schedule[i];
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: e.principal + e.interest,
                      width: 14,
                      borderRadius: BorderRadius.circular(3),
                      rodStackItems: [
                        BarChartRodStackItem(0, e.principal, AppColors.primary),
                        BarChartRodStackItem(e.principal,
                            e.principal + e.interest, AppColors.accent),
                      ],
                    ),
                  ]);
                }),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _legendDot(AppColors.primary, 'Principal'),
              const SizedBox(width: 16),
              _legendDot(AppColors.accent, 'Interest'),
            ],
          ),
          if (months > 12) ...[
            const SizedBox(height: 8),
            Text('Showing the first 12 of $months months.',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Widget _statTile(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.background, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  double _powApprox(double base, int exponent) {
    double result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}

class _ScheduleEntry {
  final int month;
  final double interest;
  final double principal;
  _ScheduleEntry(
      {required this.month, required this.interest, required this.principal});
}
