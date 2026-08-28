import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/landing_screen.dart';

/// A consistent "log out" action, meant to be dropped into the `actions` list
/// of any AppBar across the client and staff apps. Confirms before actually
/// logging out, then clears the session and returns to the landing page.
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  Future<void> _confirmAndLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of VunaFlow?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log Out')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162A1F) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xFF264634) : const Color(0xFFE5E7EB),
        ),
      ),
      child: IconButton(
        icon: const Icon(Icons.logout_rounded, color: Color(0xFFE74C3C), size: 18),
        tooltip: 'Log out',
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
        onPressed: () => _confirmAndLogout(context),
      ),
    );
  }
}
