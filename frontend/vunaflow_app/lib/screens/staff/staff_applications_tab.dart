import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/logout_button.dart';
import 'staff_loan_review_screen.dart';

class StaffApplicationsTab extends StatefulWidget {
  const StaffApplicationsTab({super.key});

  @override
  State<StaffApplicationsTab> createState() => _StaffApplicationsTabState();
}

class _StaffApplicationsTabState extends State<StaffApplicationsTab> {
  bool _loading = true;
  List<dynamic> _applications = [];
  String? _statusFilter;
  final _searchCtrl = TextEditingController();

  final _statusOptions = const [
    (null, 'All'),
    ('overdue', '🚨 Overdue (Exceeded Period)'),
    ('submitted', 'Submitted'),
    ('under_review', 'Under review'),
    ('documents_verified', 'Documents verified'),
    ('approved', 'Approved'),
    ('disbursed', 'Disbursed'),
    ('rejected', 'Rejected'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/api/loans', query: {
        if (_statusFilter != null && _statusFilter != 'overdue') 'status': _statusFilter,
        if (_searchCtrl.text.trim().isNotEmpty) 'q': _searchCtrl.text.trim(),
      });
      var list = res['data'] as List<dynamic>;

      // Filter overdue loans if overdue filter selected
      if (_statusFilter == 'overdue') {
        list = list.where((app) {
          final status = app['status'] as String;
          if (status != 'disbursed') return false;
          final createdAt = DateTime.tryParse(app['created_at'] ?? '');
          final months = int.tryParse(app['repayment_period_months']?.toString() ?? '12') ?? 12;
          final reqAmt = double.tryParse(app['amount_requested']?.toString() ?? '0') ?? 0;
          final pdAmt = double.tryParse(app['amount_paid']?.toString() ?? '0') ?? 0;
          final remaining = (reqAmt - pdAmt).clamp(0, double.infinity);
          if (remaining <= 0 || createdAt == null) return false;
          final dueDate = DateTime(createdAt.year, createdAt.month + months, createdAt.day);
          return DateTime.now().isAfter(dueDate);
        }).toList();
      }

      setState(() => _applications = list);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '??';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.parchment2,
      appBar: AppBar(
        backgroundColor: AppColors.shamba900,
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                'Signed in as ${user?.fullName ?? ''} (${user?.role})',
                style: GoogleFonts.ibmPlexMono(fontSize: 12.5, color: const Color(0xA6F5F2E7)),
              ),
            ),
          ),
          const LogoutButton(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Applications',
                      style: GoogleFonts.fraunces(fontSize: 30, fontWeight: FontWeight.w600, color: AppColors.ink),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New client'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: AppColors.parchment,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Search row
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.line),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: AppColors.inkFaint, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: GoogleFonts.publicSans(fontSize: 14.5, color: AppColors.ink),
                          decoration: InputDecoration(
                            hintText: 'Search by client name or email',
                            hintStyle: GoogleFonts.publicSans(fontSize: 14.5, color: AppColors.inkFaint),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: (_) => _load(),
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppColors.inkFaint),
                          onPressed: () {
                            _searchCtrl.clear();
                            _load();
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusOptions.map((opt) {
                      final selected = _statusFilter == opt.$1;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() => _statusFilter = opt.$1);
                            _load();
                          },
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.shamba800 : Colors.white,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: selected ? AppColors.shamba800 : AppColors.line),
                            ),
                            child: Text(
                              opt.$2,
                              style: GoogleFonts.publicSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected ? AppColors.parchment : AppColors.inkSoft,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 26),
                // List of Applications
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _applications.isEmpty
                              ? Center(
                                  child: Text(
                                    'No applications match this filter yet.',
                                    style: GoogleFonts.publicSans(fontSize: 14, color: AppColors.inkFaint),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _applications.length,
                                  itemBuilder: (context, i) {
                                    final app = _applications[i];
                                    final status = app['status'] as String;
                                    final clientName = app['client_name'] as String? ?? 'Unknown';
                                    final amount = double.tryParse(app['amount_requested'].toString()) ?? 0;
                                    final pdAmt = double.tryParse((app['amount_paid'] ?? 0).toString()) ?? 0;
                                    final remaining = (amount - pdAmt).clamp(0, double.infinity);
                                    final pctRem = amount > 0 ? ((remaining / amount) * 100) : 0.0;

                                    final createdAt = DateTime.tryParse(app['created_at'] ?? '');
                                    final months = int.tryParse(app['repayment_period_months']?.toString() ?? '12') ?? 12;
                                    bool isOverdue = false;
                                    if (status == 'disbursed' && createdAt != null && remaining > 0) {
                                      final dueDate = DateTime(createdAt.year, createdAt.month + months, createdAt.day);
                                      if (DateTime.now().isAfter(dueDate)) {
                                        isOverdue = true;
                                      }
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: isOverdue ? const Color(0xFFFFF0F0) : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: isOverdue ? Colors.redAccent.withValues(alpha: 0.5) : AppColors.line, width: isOverdue ? 1.5 : 1.0),
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
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => StaffLoanReviewScreen(loanId: app['id']),
                                            ),
                                          ).then((_) => _load());
                                        },
                                        leading: Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: isOverdue ? Colors.red.withValues(alpha: 0.15) : AppColors.parchment2,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              _getInitials(clientName),
                                              style: GoogleFonts.fraunces(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: isOverdue ? Colors.red : AppColors.shamba700,
                                              ),
                                            ),
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Text(
                                              clientName,
                                              style: GoogleFonts.publicSans(
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.ink,
                                              ),
                                            ),
                                            if (isOverdue) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                                                child: Text('OVERDUE', style: GoogleFonts.publicSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        subtitle: Text(
                                          status == 'disbursed'
                                              ? 'KSh ${amount.toStringAsFixed(0)} · Paid: KSh ${pdAmt.toStringAsFixed(0)} (${pctRem.toStringAsFixed(0)}% Due)'
                                              : 'KSh ${amount.toStringAsFixed(0)} · ${app['branch_name'] ?? 'No branch'}',
                                          style: GoogleFonts.ibmPlexMono(
                                            fontSize: 12.5,
                                            fontWeight: status == 'disbursed' ? FontWeight.w600 : FontWeight.w400,
                                            color: isOverdue ? const Color(0xFFC0392B) : AppColors.inkSoft,
                                          ),
                                        ),
                                        trailing: _buildStatusBadge(status),
                                      ),
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFE4EEF1);
    Color fg = AppColors.sky;
    IconData icon = Icons.info_outline;

    if (status == 'approved') {
      bg = const Color(0xFFE4EFE6);
      fg = AppColors.shamba700;
      icon = Icons.check;
    } else if (status == 'rejected') {
      bg = const Color(0xFFF6E3DF);
      fg = AppColors.brick;
      icon = Icons.close;
    } else if (status == 'disbursed') {
      bg = AppColors.goldPale;
      fg = AppColors.goldDark;
      icon = Icons.verified;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            statusLabel(status),
            style: GoogleFonts.publicSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
