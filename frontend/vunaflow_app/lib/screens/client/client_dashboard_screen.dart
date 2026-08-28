import 'package:flutter/material.dart';
import 'client_home_tab.dart';
import 'loan_application_screen.dart';
import 'loan_tracking_screen.dart';
import 'assistant_screen.dart';
import 'profile_screen.dart';

/// Root shell for a logged-in client: bottom navigation across
/// Home, Loans, Assistant, and Profile.
class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  int _index = 0;

  final _screens = const [
    ClientHomeTab(),
    LoanTrackingScreen(embedded: true),
    AssistantScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryActiveColor = isDark ? const Color(0xFF34D399) : const Color(0xFF133826);
    final unselectedColor = isDark ? const Color(0xFF8BA596) : const Color(0xFF6B7280);

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: (_index == 0 || _index == 1)
          ? FloatingActionButton.extended(
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
