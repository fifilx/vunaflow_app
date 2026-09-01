import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/logout_button.dart';
import '../../widgets/theme_toggle_button.dart';

class StaffReportsTab extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const StaffReportsTab({super.key, this.onOpenDrawer});

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
    final appBarBg = isDark ? const Color(0xFF0F1B14) : const Color(0xFF133826);
    final scaffoldBg = isDark ? const Color(0xFF0C1610) : const Color(0xFFF9F8F5);

    final isDesktop = MediaQuery.sizeOf(context).width >= 840;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: !isDesktop
            ? IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                tooltip: 'Open Side Panel',
                onPressed: widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
              )
            : null,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.spa_outlined, color: Color(0xFFD4AF37), size: 22),
            SizedBox(width: 8),
            Text('Reports & Analytics', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: const [ThemeToggleButton(), LogoutButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isDesktop = width >= 860;

                final statItems = [
                  (label: 'Total Loans', value: '${_summary?['total_loans'] ?? 0}', color: const Color(0xFF16A34A)),
                  (label: 'Pending', value: '${_summary?['pending_loans'] ?? 0}', color: const Color(0xFFD97706)),
                  (label: 'Approved', value: '${_summary?['approved_loans'] ?? 0}', color: const Color(0xFF2563EB)),
                  (label: 'Rejected', value: '${_summary?['rejected_loans'] ?? 0}', color: const Color(0xFFDC2626)),
                  (label: 'Disbursed', value: '${_summary?['disbursed_loans'] ?? 0}', color: const Color(0xFF059669)),
                  (label: 'Total Clients', value: '${_summary?['total_clients'] ?? 0}', color: const Color(0xFF7C3AED)),
                ];

                return RefreshIndicator(
                  onRefresh: _load,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: ListView(
                        padding: EdgeInsets.all(isDesktop ? 24 : 14),
                        children: [
                          Text('Summary Overview', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: width < 480 ? 2 : (width < 768 ? 3 : 6),
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              mainAxisExtent: 78,
                            ),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: statItems.length,
                            itemBuilder: (context, i) {
                              final item = statItems[i];
                              return _ReportStat(
                                label: item.label,
                                value: item.value,
                                color: item.color,
                                isDark: isDark,
                              );
                            },
                          ),
                          const SizedBox(height: 24),

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
                              const SizedBox(height: 28),
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
                                        ..._buildBranchBars(_analytics!['applications_by_branch'] as List<dynamic>, isDark, width),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text('Applications by Month', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              SizedBox(height: 220, child: _MonthlyBarChart(data: _analytics!['applications_by_month'] as List<dynamic>, isDark: isDark)),
                              const SizedBox(height: 24),

                              Text('Approved vs Rejected', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              SizedBox(height: 220, child: _ApprovedVsRejectedChart(data: _analytics!['approved_vs_rejected'] as List<dynamic>)),
                              const SizedBox(height: 24),

                              Text('Loan Amounts', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              _LoanAmountsCard(data: _analytics!['loan_amounts'] as Map<String, dynamic>, isDark: isDark),
                              const SizedBox(height: 24),

                              Text('Applications by Branch', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              ..._buildBranchBars(_analytics!['applications_by_branch'] as List<dynamic>, isDark, width),
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

  List<Widget> _buildBranchBars(List<dynamic> data, bool isDark, double width) {
    final maxCount = data.fold<int>(1, (m, e) => (int.parse(e['count'].toString())) > m ? int.parse(e['count'].toString()) : m);
    final isSmall = width < 480;

    return data.map((e) {
      final count = int.parse(e['count'].toString());
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(
              width: isSmall ? 85 : 120,
              child: Text(
                e['branch'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: count / maxCount,
                  minHeight: 12,
                  backgroundColor: isDark ? const Color(0xFF223C2D) : const Color(0xFFE5E7EB),
                  color: const Color(0xFF16A34A),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('$count', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14241B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF223C2D) : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF9EBAA9) : const Color(0xFF6B7280),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
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
                  child: Text(month.length > 5 ? month.substring(5) : month, style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF9EBAA9) : Colors.grey)),
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
              width: 14,
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
              centerSpaceRadius: 36,
              sections: [
                PieChartSectionData(value: approvedVal, color: AppColors.success, title: '${approvedVal.toInt()}', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                PieChartSectionData(value: rejectedVal, color: AppColors.danger, title: '${rejectedVal.toInt()}', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)), const SizedBox(width: 6), const Text('Approved', style: TextStyle(fontSize: 12.5))]),
            const SizedBox(height: 8),
            Row(children: [Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle)), const SizedBox(width: 6), const Text('Rejected', style: TextStyle(fontSize: 12.5))]),
          ],
        ),
        const SizedBox(width: 12),
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
    final border = isDark ? const Color(0xFF223C2D) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14241B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          _row(context, 'Total Amount Requested', _fmt(data['total_amount']), border),
          _row(context, 'Average Amount', _fmt(data['average_amount']), border),
          _row(context, 'Minimum Amount', _fmt(data['min_amount']), border),
          _row(context, 'Maximum Amount', _fmt(data['max_amount']), border, isLast: true),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, Color border, {bool isLast = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(label, style: const TextStyle(fontSize: 13.5), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          ],
        ),
      );
}
