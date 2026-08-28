import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/landing_screen.dart';
import 'screens/client/client_dashboard_screen.dart';
import 'screens/staff/staff_dashboard_screen.dart';

void main() {
  runApp(const VunaFlowApp());
}

class VunaFlowApp extends StatelessWidget {
  const VunaFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'VunaFlow',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            home: const _RootRouter(),
          );
        },
      ),
    );
  }
}

/// Decides which screen to show first: a splash loader while checking for a
/// saved session, then either the landing page or the right dashboard.
class _RootRouter extends StatefulWidget {
  const _RootRouter();

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().tryAutoLogin();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.loading) {
      return const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.eco_rounded, color: Colors.white, size: 56),
              SizedBox(height: 16),
              Text('VunaFlow', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
              SizedBox(height: 24),
              CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      );
    }

    if (!auth.isLoggedIn) return const LandingScreen();
    if (auth.user!.isStaff) return const StaffDashboardScreen();
    return const ClientDashboardScreen();
  }
}
