import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/vunaflow_logo.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../widgets/logout_button.dart';
import 'client_home_tab.dart';
import 'loan_application_screen.dart';
import 'loan_tracking_screen.dart';
import 'assistant_screen.dart';
import 'profile_screen.dart';

/// Root shell for a logged-in client:
/// - Desktop (>= 840px): Sleek collapsible Navigation Sidebar with auto-hide/compact mode.
/// - Mobile (< 840px): Standard bottom navigation bar with FAB.
class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  int _index = 0;
  bool _sidebarCollapsed = false;

  final _screens = const [
    ClientHomeTab(),
    LoanTrackingScreen(embedded: true),
    AssistantScreen(),
    ProfileScreen(),
  ];

  final _navItems = const [
    (icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.ssid_chart, selectedIcon: Icons.ssid_chart, label: 'Loans'),
    (icon: Icons.chat_bubble_outline_rounded, selectedIcon: Icons.chat_bubble_rounded, label: 'Assistant'),
    (icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 840;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryActiveColor = isDark ? const Color(0xFF34D399) : const Color(0xFF133826);
    final unselectedColor = isDark ? const Color(0xFF8BA596) : const Color(0xFF6B7280);
    final sidebarBg = isDark ? const Color(0xFF0F1B14) : Colors.white;
    final sidebarBorder = isDark ? const Color(0xFF1B3224) : const Color(0xFFE5E7EB);
    final activePillBg = isDark ? const Color(0xFF1B3D2A) : const Color(0xFFE8F5E9);

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Responsive Animated Collapsible Sidebar
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
                  const SizedBox(height: 16),
                  // Header with Logo and Collapse Toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisAlignment: _sidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                      children: [
                        if (!_sidebarCollapsed)
                          const VunaFlowLogo(size: 28, showWordmark: true)
                        else
                          const VunaFlowLogo(size: 28, showWordmark: false),
                        if (!_sidebarCollapsed)
                          IconButton(
                            icon: const Icon(Icons.menu_open, size: 20),
                            color: unselectedColor,
                            tooltip: 'Collapse sidebar',
                            onPressed: () => setState(() => _sidebarCollapsed = true),
                          ),
                      ],
                    ),
                  ),
                  if (_sidebarCollapsed) ...[
                    const SizedBox(height: 8),
                    IconButton(
                      icon: const Icon(Icons.menu, size: 20),
                      color: unselectedColor,
                      tooltip: 'Expand sidebar',
                      onPressed: () => setState(() => _sidebarCollapsed = false),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // "+ New Loan" Action Button in Sidebar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: _sidebarCollapsed ? 12 : 14),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoanApplicationScreen()),
                        ),
                        icon: const Icon(Icons.add, size: 18, color: Colors.white),
                        label: _sidebarCollapsed
                            ? const SizedBox.shrink()
                            : const Text('New Loan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF163E27) : const Color(0xFF133826),
                          padding: EdgeInsets.symmetric(horizontal: _sidebarCollapsed ? 0 : 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Navigation Items List
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: _navItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, i) {
                        final item = _navItems[i];
                        final isSelected = _index == i;

                        return Tooltip(
                          message: _sidebarCollapsed ? item.label : '',
                          child: InkWell(
                            onTap: () => setState(() => _index = i),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: EdgeInsets.symmetric(horizontal: _sidebarCollapsed ? 0 : 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? activePillBg : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: _sidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                                children: [
                                  Icon(
                                    isSelected ? item.selectedIcon : item.icon,
                                    color: isSelected ? primaryActiveColor : unselectedColor,
                                    size: 22,
                                  ),
                                  if (!_sidebarCollapsed) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        style: GoogleFonts.publicSans(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? primaryActiveColor : unselectedColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Sidebar Footer (Theme Toggle & Logout)
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
              child: IndexedStack(index: _index, children: _screens),
            ),
          ],
        ),
      );
    }

    // Mobile / Narrow Layout
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: (_index == 0 || _index == 1)
          ? FloatingActionButton.extended(
              heroTag: 'client_dashboard_fab',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoanApplicationScreen()),
              ),
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
              label: const Text(
                'New Loan',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
              backgroundColor: isDark ? const Color(0xFF1A4630) : const Color(0xFF133826),
              elevation: 4,
              shape: const StadiumBorder(),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: isDark ? const Color(0xFF0F1B14) : Colors.white,
        indicatorColor: isDark ? const Color(0xFF1B3D2A) : const Color(0xFFD8F3DC),
        elevation: 8,
        surfaceTintColor: Colors.transparent,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: unselectedColor),
            selectedIcon: Icon(Icons.home_rounded, color: primaryActiveColor),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.ssid_chart, color: unselectedColor),
            selectedIcon: Icon(Icons.ssid_chart, color: primaryActiveColor),
            label: 'Loans',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded, color: unselectedColor),
            selectedIcon: Icon(Icons.chat_bubble_rounded, color: primaryActiveColor),
            label: 'Assistant',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded, color: unselectedColor),
            selectedIcon: Icon(Icons.person_rounded, color: primaryActiveColor),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

