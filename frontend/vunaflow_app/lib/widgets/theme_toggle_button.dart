import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// A circular button to quickly toggle between Light Mode and Dark Mode.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162A1F) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xFF264634) : const Color(0xFFE5E7EB),
        ),
      ),
      child: IconButton(
        icon: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          color: isDark ? const Color(0xFFFDE047) : const Color(0xFF1F2937),
          size: 18,
        ),
        tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
        onPressed: () => context.read<ThemeProvider>().toggleTheme(),
      ),
    );
  }
}
