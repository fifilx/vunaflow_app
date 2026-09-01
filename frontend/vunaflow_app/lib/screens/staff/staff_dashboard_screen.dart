import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../widgets/logout_button.dart';
import '../../widgets/vunaflow_logo.dart';
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
  bool _sidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user?.isAdmin ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryActiveColor = isDark ? const Color(0xFF34D399) : const Color(0xFF133826);
    final unselectedColor = isDark ? const Color(0xFF8BA596) : const Color(0xFF6B7280);

    final sidebarBg = isDark ? const Color(0xFF0F1B14) : const Color(0xFFF9F8F5);
    final sidebarBorder = isDark ? const Color(0xFF1B3D2A) : const Color(0xFFE5E7EB);
    final selectedItemBg = isDark ? const Color(0xFF1B3D2A) : const Color(0xFFD8F3DC);
    final textPrimary = isDark ? const Color(0xFFF4F6F0) : const Color(0xFF1F2937);

    final screens = [
      StaffApplicationsTab(onOpenDrawer: _openDrawer),
      StaffReportsTab(onOpenDrawer: _openDrawer),
      if (isAdmin) StaffAdminTab(onOpenDrawer: _openDrawer),
    ];

    final navItems = [
      (Icons.list_alt_outlined, Icons.list_alt, 'Applications'),
      (Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
      if (isAdmin)
        (Icons.admin_panel_settings_outlined, Icons.admin_panel_settings, 'Admin'),
    ];

    Widget buildDrawerContent({required bool inDrawer}) {
      return Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            color: isDark ? const Color(0xFF0F1B14) : const Color(0xFF133826),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  const VunaFlowLogo(size: 32, showWordmark: true, textColor: Colors.white),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isAdmin ? 'ADMIN' : 'STAFF',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF133826),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (user != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isDark ? const Color(0xFF14241B) : const Color(0xFFE8F5E9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: GoogleFonts.publicSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? const Color(0xFFF4F6F0) : const Color(0xFF133826),
                    ),
                  ),
                  Text(
                    user.email,
                    style: GoogleFonts.publicSans(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9EBAA9) : const Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 1),

          // Navigation Links
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              itemCount: navItems.length,
              itemBuilder: (context, i) {
                final item = navItems[i];
                final isSelected = _index == i;
                final iconData = isSelected ? item.$2 : item.$1;
                final label = item.$3;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: InkWell(
                    onTap: () {
                      setState(() => _index = i);
                      if (inDrawer) Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? selectedItemBg : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            iconData,
                            color: isSelected ? primaryActiveColor : unselectedColor,
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            label,
                            style: GoogleFonts.publicSans(
                              fontSize: 14.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? primaryActiveColor : textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Drawer Footer Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: sidebarBorder)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ThemeToggleButton(),
                LogoutButton(),
              ],
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 840;

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                // Collapsible Desktop Sidebar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  width: _sidebarCollapsed ? 76 : 230,
                  decoration: BoxDecoration(
                    color: sidebarBg,
                    border: Border(right: BorderSide(color: sidebarBorder)),
                  ),
                  child: Column(
                    children: [
                      // Sidebar Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        child: Row(
                          mainAxisAlignment: _sidebarCollapsed
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.spaceBetween,
                          children: [
                            if (!_sidebarCollapsed) ...[
                              Row(
                                children: [
                                  const VunaFlowLogo(size: 26, showWordmark: false),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'VunaFlow',
                                        style: GoogleFonts.fraunces(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF163E27) : const Color(0xFFE8F5E9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isAdmin ? 'ADMIN PORTAL' : 'STAFF PORTAL',
                                          style: GoogleFonts.ibmPlexMono(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534),
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                            IconButton(
                              icon: Icon(
                                _sidebarCollapsed ? Icons.menu : Icons.menu_open,
                                size: 20,
                                color: unselectedColor,
                              ),
                              tooltip: _sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
                              onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 10),

                      // Navigation Rail Items
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          itemCount: navItems.length,
                          itemBuilder: (context, i) {
                            final item = navItems[i];
                            final isSelected = _index == i;
                            final iconData = isSelected ? item.$2 : item.$1;
                            final label = item.$3;

                            if (_sidebarCollapsed) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Tooltip(
                                  message: label,
                                  child: InkWell(
                                    onTap: () => setState(() => _index = i),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: isSelected ? selectedItemBg : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          iconData,
                                          color: isSelected ? primaryActiveColor : unselectedColor,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: InkWell(
                                onTap: () => setState(() => _index = i),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: isSelected ? selectedItemBg : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        iconData,
                                        color: isSelected ? primaryActiveColor : unselectedColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 14),
                                      Text(
                                        label,
                                        style: GoogleFonts.publicSans(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? primaryActiveColor : textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Bottom Sidebar Footer
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: sidebarBorder)),
                        ),
                        child: _sidebarCollapsed
                            ? const Column(
                                children: [
                                  ThemeToggleButton(),
                                  SizedBox(height: 6),
                                  LogoutButton(),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  ThemeToggleButton(),
                                  LogoutButton(),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),

                // Main Content View
                Expanded(
                  child: IndexedStack(index: _index, children: screens),
                ),
              ],
            ),
          );
        }

        // Mobile Layout with Drawer & Bottom Navigation Bar
        return Scaffold(
          key: _scaffoldKey,
          drawer: Drawer(
            child: buildDrawerContent(inDrawer: true),
          ),
          body: IndexedStack(index: _index, children: screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            backgroundColor: isDark ? const Color(0xFF0F1B14) : Colors.white,
            indicatorColor: isDark ? const Color(0xFF1B3D2A) : const Color(0xFFD8F3DC),
            elevation: 8,
            surfaceTintColor: Colors.transparent,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: navItems.map((item) {
              return NavigationDestination(
                icon: Icon(item.$1, color: unselectedColor),
                selectedIcon: Icon(item.$2, color: primaryActiveColor),
                label: item.$3,
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
