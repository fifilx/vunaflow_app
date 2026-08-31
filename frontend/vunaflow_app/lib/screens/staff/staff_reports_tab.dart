import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/logout_button.dart';
import '../../widgets/theme_toggle_button.dart';

class StaffReportsTab extends StatefulWidget {
  const StaffReportsTab({super.key});

  @override
  State<StaffReportsTab> createState() => _StaffReportsTabState();
}

class _StaffReportsTabState extends State<StaffReportsTab> {
  bool _loading = true;
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _analytics;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.get('/api/reports/summary'),
        ApiService.get('/api/reports/analytics'),
      ]);
      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _analytics = results[1] as Map<String, dynamic>;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: const [ThemeToggleButton(), LogoutButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isDesktop = width >= 860;

                return RefreshIndicator(
                  onRefresh: _load,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: ListView(
                        padding: EdgeInsets.all(isDesktop ? 24 : 16),
                        children: [
                          Text('Summary', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: width < 600 ? 2 : (width < 960 ? 3 : 6),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.5,
                            children: [
                              _ReportStat(label: 'Total Loans', value: '${_summary?['total_loans'] ?? 0}', color: AppColors.primary, isDark: isDark),
                              _ReportStat(label: 'Pending', value: '${_summary?['pending_loans'] ?? 0}', color: AppColors.warning, isDark: isDark),
                              _ReportStat(label: 'Approved', value: '${_summary?['approved_loans'] ?? 0}', color: AppColors.success, isDark: isDark),
                              _ReportStat(label: 'Rejected', value: '${_summary?['rejected_loans'] ?? 0}', color: AppColors.danger, isDark: isDark),
                              _ReportStat(label: 'Disbursed', value: '${_summary?['disbursed_loans'] ?? 0}', color: AppColors.info, isDark: isDark),
                              _ReportStat(label: 'Total Clients', value: '${_summary?['total_clients'] ?? 0}', color: AppColors.accentDark, isDark: isDark),
                            ],
                          ),
                          const SizedBox(height: 32),

                          if (_analytics != null) ...[
                            if (isDesktop) ...[
                              // Desktop 2-column side-by-side charts
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Applications by Month', style: Theme.of(context).textTheme.titleLarge),
                                        const SizedBox(height: 12),
                                        SizedBox(height: 240, child: _MonthlyBarChart(data: _analytics!['applications_by_month'] as List<dynamic>, isDark: isDark)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Approved vs Rejected', style: Theme.of(context).textTheme.titleLarge),
                                        const SizedBox(height: 12),
                                        SizedBox(height: 240, child: _ApprovedVsRejectedChart(data: _analytics!['approved_vs_rejected'] as List<dynamic>)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Loan Amounts', style: Theme.of(context).textTheme.titleLarge),
                                        const SizedBox(height: 12),
                                        _LoanAmountsCard(data: _analytics!['loan_amounts'] as Map<String, dynamic>, isDark: isDark),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Applications by Branch', style: Theme.of(context).textTheme.titleLarge),
                                        const SizedBox(height: 12),
                                        ..._buildBranchBars(_analytics!['applications_by_branch'] as List<dynamic>, isDark),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text('Applications by Month', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              SizedBox(height: 220, child: _MonthlyBarChart(data: _analytics!['applications_by_month'] as List<dynamic>, isDark: isDark)),
                              const SizedBox(height: 32),

                              Text('Approved vs Rejected', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              SizedBox(height: 220, child: _ApprovedVsRejectedChart(data: _analytics!['approved_vs_rejected'] as List<dynamic>)),
                              const SizedBox(height: 32),

                              Text('Loan Amounts', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              _LoanAmountsCard(data: _analytics!['loan_amounts'] as Map<String, dynamic>, isDark: isDark),
                              const SizedBox(height: 32),

                              Text('Applications by Branch', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              ..._buildBranchBars(_analytics!['applications_by_branch'] as List<dynamic>, isDark),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  List<Widget> _buildBranchBars(List<dynamic> data, bool isDark) {
    final maxCount = data.fold<int>(1, (m, e) => (int.parse(e['count'].toString())) > m ? int.parse(e['count'].toString()) : m);
    return data.map((e) {
      final count = int.parse(e['count'].toString());
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(width: 130, child: Text(e['branch'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: count / maxCount,
                  minHeight: 14,
                  backgroundColor: AppColors.border,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('$count'),
          ],
        ),
      );
    }).toList();
  }
}

class _ReportStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _ReportStat({required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14241B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF223C2D) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final List<dynamic> data;
  final bool isDark;
  const _MonthlyBarChart({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No data yet.'));
    final maxY = data.fold<double>(1, (m, e) => double.parse(e['count'].toString()) > m ? double.parse(e['count'].toString()) : m);
    final gridColor = isDark ? const Color(0xFF223C2D) : Colors.grey.shade200;

    return BarChart(
      BarChartData(
        maxY: maxY + 1,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(color: gridColor, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, m) => Text('${v.toInt()}', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF9EBAA9) : Colors.grey)),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                final month = data[i]['month'].toString();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(month.substring(5), style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF9EBAA9) : Colors.grey)),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(data.length, (i) {
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: double.parse(data[i]['count'].toString()),
              color: isDark ? const Color(0xFF34D399) : AppColors.primary,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ]);
        }),
      ),
    );
  }
}

class _ApprovedVsRejectedChart extends StatelessWidget {
  final List<dynamic> data;
  const _ApprovedVsRejectedChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final approved = data.firstWhere((e) => e['status'] == 'approved', orElse: () => {'count': 0})['count'];
    final rejected = data.firstWhere((e) => e['status'] == 'rejected', orElse: () => {'count': 0})['count'];
    final approvedVal = double.parse(approved.toString());
    final rejectedVal = double.parse(rejected.toString());
    final total = approvedVal + rejectedVal;

    if (total == 0) return const Center(child: Text('No approved or rejected loans yet.'));

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 40,
              sections: [
                PieChartSectionData(value: approvedVal, color: AppColors.success, title: '${approvedVal.toInt()}', radius: 60, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                PieChartSectionData(value: rejectedVal, color: AppColors.danger, title: '${rejectedVal.toInt()}', radius: 60, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Container(width: 12, height: 12, color: AppColors.success), const SizedBox(width: 6), const Text('Approved')]),
            const SizedBox(height: 8),
            Row(children: [Container(width: 12, height: 12, color: AppColors.danger), const SizedBox(width: 6), const Text('Rejected')]),
          ],
        ),
        const SizedBox(width: 20),
      ],
    );
  }
}

class _LoanAmountsCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  const _LoanAmountsCard({required this.data, required this.isDark});

  String _fmt(dynamic v) => fmtKsh(v);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14241B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF223C2D) : AppColors.border),
      ),
      child: Column(
        children: [
          _row(context, 'Total Amount Requested', _fmt(data['total_amount'])),
          _row(context, 'Average Amount', _fmt(data['average_amount'])),
          _row(context, 'Minimum Amount', _fmt(data['min_amount'])),
          _row(context, 'Maximum Amount', _fmt(data['max_amount'])),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))]),
      );
}
