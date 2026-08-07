import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
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
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoanApplicationScreen())),
              icon: const Icon(Icons.add),
              label: const Text('New Loan'),
              backgroundColor: AppColors.primary,
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.timeline_outlined), selectedIcon: Icon(Icons.timeline), label: 'Loans'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), selectedIcon: Icon(Icons.smart_toy), label: 'Assistant'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
