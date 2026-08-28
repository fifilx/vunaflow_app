import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'staff_applications_tab.dart';
import 'staff_reports_tab.dart';
import 'staff_admin_tab.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user?.isAdmin ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryActiveColor = isDark ? const Color(0xFF34D399) : const Color(0xFF133826);
    final unselectedColor = isDark ? const Color(0xFF8BA596) : const Color(0xFF6B7280);

    final screens = [
      const StaffApplicationsTab(),
      const StaffReportsTab(),
      if (isAdmin) const StaffAdminTab(),
    ];

    final destinations = [
      NavigationDestination(
        icon: Icon(Icons.list_alt_outlined, color: unselectedColor),
        selectedIcon: Icon(Icons.list_alt, color: primaryActiveColor),
        label: 'Applications',
      ),
      NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined, color: unselectedColor),
        selectedIcon: Icon(Icons.bar_chart, color: primaryActiveColor),
        label: 'Reports',
      ),
      if (isAdmin)
        NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined, color: unselectedColor),
          selectedIcon: Icon(Icons.admin_panel_settings, color: primaryActiveColor),
          label: 'Admin',
        ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: isDark ? const Color(0xFF0F1B14) : Colors.white,
        indicatorColor: isDark ? const Color(0xFF1B3D2A) : const Color(0xFFD8F3DC),
        elevation: 8,
        surfaceTintColor: Colors.transparent,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}
