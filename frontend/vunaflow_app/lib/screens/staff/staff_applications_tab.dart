import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/logout_button.dart';
import '../../widgets/theme_toggle_button.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0C1610) : AppColors.parchment2;
    final appBarBg = isDark ? const Color(0xFF0F1B14) : AppColors.shamba900;
    final cardBg = isDark ? const Color(0xFF14241B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF223C2D) : AppColors.line;
    final textPrimary = isDark ? const Color(0xFFF4F6F0) : AppColors.ink;
    final textMuted = isDark ? const Color(0xFF9EBAA9) : AppColors.inkSoft;
    final chipSelected = isDark ? const Color(0xFF1B3D2A) : AppColors.shamba800;
    final chipUnselected = isDark ? const Color(0xFF14241B) : Colors.white;
    final chipBorderUnselected = isDark ? const Color(0xFF223C2D) : AppColors.line;

    return Scaffold(
      backgroundColor: bgColor,
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                'Signed in as ${user?.fullName ?? ''} (${user?.role})',
                style: GoogleFonts.ibmPlexMono(fontSize: 12.5, color: const Color(0xA6F5F2E7)),
              ),
            ),
          ),
          const ThemeToggleButton(),
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
                      style: GoogleFonts.fraunces(fontSize: 30, fontWeight: FontWeight.w600, color: textPrimary),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New client'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF2ECC71) : AppColors.ink,
                        foregroundColor: isDark ? const Color(0xFF0C1610) : AppColors.parchment,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Search row
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: cardBorder),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: textMuted, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: GoogleFonts.publicSans(fontSize: 14.5, color: textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search by client name or email',
                            hintStyle: GoogleFonts.publicSans(fontSize: 14.5, color: textMuted),
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
                          icon: Icon(Icons.close, size: 18, color: textMuted),
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
                              color: selected ? chipSelected : chipUnselected,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: selected ? chipSelected : chipBorderUnselected),
                            ),
                            child: Text(
                              opt.$2,
                              style: GoogleFonts.publicSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected ? (isDark ? const Color(0xFF6EE7B7) : AppColors.parchment) : textMuted,
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
                                    style: GoogleFonts.publicSans(fontSize: 14, color: textMuted),
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

                                    final overdueBg = isDark ? const Color(0xFF2A1414) : const Color(0xFFFFF0F0);
                                    final overdueBorder = isDark ? Colors.red.withValues(alpha: 0.4) : Colors.redAccent.withValues(alpha: 0.5);

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: isOverdue ? overdueBg : cardBg,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: isOverdue ? overdueBorder : cardBorder, width: isOverdue ? 1.5 : 1.0),
                                        boxShadow: isDark ? [] : const [
                                          BoxShadow(color: Color.fromRGBO(34, 36, 30, 0.04), blurRadius: 2, offset: Offset(0, 1)),
                                          BoxShadow(color: Color.fromRGBO(34, 36, 30, 0.06), blurRadius: 24, offset: Offset(0, 8)),
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
                                            color: isOverdue
                                                ? Colors.red.withValues(alpha: 0.15)
                                                : (isDark ? const Color(0xFF1B3D2A) : AppColors.parchment2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              _getInitials(clientName),
                                              style: GoogleFonts.fraunces(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: isOverdue ? Colors.red : (isDark ? const Color(0xFF34D399) : AppColors.shamba700),
                                              ),
                                            ),
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                clientName,
                                                style: GoogleFonts.publicSans(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: textPrimary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
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
                                              ? '${fmtKsh(amount)} · Paid: ${fmtKsh(pdAmt)} (${pctRem.toStringAsFixed(0)}% Due)'
                                              : '${fmtKsh(amount)} · ${app['branch_name'] ?? 'No branch'}',
                                          style: GoogleFonts.ibmPlexMono(
                                            fontSize: 12.5,
                                            fontWeight: status == 'disbursed' ? FontWeight.w600 : FontWeight.w400,
                                            color: isOverdue ? const Color(0xFFC0392B) : textMuted,
                                          ),
                                        ),
                                        trailing: _buildStatusBadge(status, isDark),
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

  Widget _buildStatusBadge(String status, bool isDark) {
    Color bg = isDark ? const Color(0xFF163040) : const Color(0xFFE4EEF1);
    Color fg = isDark ? const Color(0xFF7EC8E3) : AppColors.sky;
    IconData icon = Icons.info_outline;

    if (status == 'approved') {
      bg = isDark ? const Color(0xFF163E27) : const Color(0xFFE4EFE6);
      fg = isDark ? const Color(0xFF6EE7B7) : AppColors.shamba700;
      icon = Icons.check;
    } else if (status == 'rejected') {
      bg = isDark ? const Color(0xFF3A1A1A) : const Color(0xFFF6E3DF);
      fg = isDark ? const Color(0xFFFF9B8A) : AppColors.brick;
      icon = Icons.close;
    } else if (status == 'disbursed') {
      bg = isDark ? const Color(0xFF2E2600) : AppColors.goldPale;
      fg = isDark ? const Color(0xFFFFD700) : AppColors.goldDark;
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

