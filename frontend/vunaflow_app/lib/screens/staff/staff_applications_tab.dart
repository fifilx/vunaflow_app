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
  final VoidCallback? onOpenDrawer;
  const StaffApplicationsTab({super.key, this.onOpenDrawer});

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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 840;

    final bgColor = isDark ? const Color(0xFF0C1610) : const Color(0xFFF9F8F5);
    final appBarBg = isDark ? const Color(0xFF0F1B14) : const Color(0xFF133826);
    final cardBg = isDark ? const Color(0xFF14241B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF223C2D) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? const Color(0xFFF4F6F0) : const Color(0xFF1F2937);
    final textMuted = isDark ? const Color(0xFF9EBAA9) : const Color(0xFF6B7280);
    final chipSelected = isDark ? const Color(0xFF1B3D2A) : const Color(0xFF133826);
    final chipUnselected = isDark ? const Color(0xFF14241B) : Colors.white;
    final chipBorderUnselected = isDark ? const Color(0xFF223C2D) : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: bgColor,
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.spa_outlined, color: Color(0xFFD4AF37), size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'VunaFlow · Staff',
                style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (isDesktop && user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '${user.fullName} (${user.role})',
                  style: GoogleFonts.ibmPlexMono(fontSize: 12, color: const Color(0xA6F5F2E7)),
                ),
              ),
            ),
          const ThemeToggleButton(),
          const LogoutButton(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 28 : 16,
              vertical: isDesktop ? 24 : 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Applications',
                        style: GoogleFonts.fraunces(
                          fontSize: isDesktop ? 28 : 22,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_applications.length} on file',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: textMuted, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: GoogleFonts.publicSans(fontSize: 14, color: textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search by client name or email...',
                            hintStyle: GoogleFonts.publicSans(fontSize: 13.5, color: textMuted),
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
                const SizedBox(height: 14),

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected ? chipSelected : chipUnselected,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: selected ? chipSelected : chipBorderUnselected),
                            ),
                            child: Text(
                              opt.$2,
                              style: GoogleFonts.publicSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: selected ? (isDark ? const Color(0xFF6EE7B7) : Colors.white) : textMuted,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

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
                                    final app = _applications[i] as Map<String, dynamic>;
                                    final statusInfo = getDetailedLoanStatus(app);
                                    final clientName = app['client_name'] as String? ?? 'Applicant';
                                    final amount = double.tryParse(app['amount_requested']?.toString() ?? '0') ?? 0.0;
                                    final pdAmt = double.tryParse(app['amount_paid']?.toString() ?? '0') ?? 0.0;
                                    final remaining = (amount - pdAmt).clamp(0.0, double.infinity);
                                    final branch = app['branch_name'] as String? ?? 'Head Office';

                                    final overdueBg = isDark ? const Color(0xFF2A1414) : const Color(0xFFFFF0F0);
                                    final overdueBorder = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5);

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: statusInfo.isOverdue ? overdueBg : cardBg,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: statusInfo.isOverdue ? overdueBorder : cardBorder,
                                          width: statusInfo.isOverdue ? 1.5 : 1.0,
                                        ),
                                        boxShadow: isDark
                                            ? []
                                            : [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.03),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(14),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(14),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => StaffLoanReviewScreen(loanId: app['id']),
                                              ),
                                            ).then((_) => _load());
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(14),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                // Avatar / Initials
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: statusInfo.isOverdue
                                                        ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                                                        : (isDark ? const Color(0xFF1B3D2A) : const Color(0xFFE8F5E9)),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      _getInitials(clientName),
                                                      style: GoogleFonts.fraunces(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w700,
                                                        color: statusInfo.isOverdue
                                                            ? const Color(0xFFDC2626)
                                                            : (isDark ? const Color(0xFF34D399) : const Color(0xFF166534)),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),

                                                // Client Details Column
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              clientName,
                                                              style: GoogleFonts.publicSans(
                                                                fontSize: 15,
                                                                fontWeight: FontWeight.w700,
                                                                color: textPrimary,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          if (statusInfo.isOverdue) ...[
                                                            const SizedBox(width: 6),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFDC2626),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: Text(
                                                                'OVERDUE',
                                                                style: GoogleFonts.publicSans(
                                                                  color: Colors.white,
                                                                  fontSize: 9,
                                                                  fontWeight: FontWeight.w800,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        statusInfo.isActive
                                                            ? '${fmtKsh(amount)} · Paid ${fmtKsh(pdAmt)} (${fmtKsh(remaining)} due)'
                                                            : '${fmtKsh(amount)} · $branch',
                                                        style: GoogleFonts.ibmPlexMono(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                          color: statusInfo.isOverdue ? const Color(0xFFEF4444) : textMuted,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),

                                                // Status Badge
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                                                  decoration: BoxDecoration(
                                                    color: statusInfo.badgeBg(isDark),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    statusInfo.fullTitle,
                                                    style: GoogleFonts.publicSans(
                                                      color: statusInfo.badgeFg(isDark),
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
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
}

