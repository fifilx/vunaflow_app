import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/logout_button.dart';
import '../landing_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  List<dynamic> _advice = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/api/profile');
      setState(() => _data = res);
      final farm = res['farmer_profile'] ?? {};
      final crop = farm['primary_crop'];
      final livestock = farm['livestock_type'];

      final List<dynamic> combinedAdvice = [];
      if (crop != null && crop.toString().isNotEmpty) {
        final cropAdvice = await ApiService.get('/api/farming-advice', query: {'crop': crop});
        combinedAdvice.addAll(cropAdvice as List<dynamic>);
      }
      if (livestock != null && livestock.toString().isNotEmpty) {
        final livestockAdvice = await ApiService.get('/api/farming-advice', query: {'crop': livestock});
        combinedAdvice.addAll(livestockAdvice as List<dynamic>);
      }
      if (combinedAdvice.isEmpty) {
        final defaultAdvice = await ApiService.get('/api/farming-advice');
        combinedAdvice.addAll((defaultAdvice as List<dynamic>).take(3));
      }
      setState(() => _advice = combinedAdvice);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LandingScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_data == null) return const Scaffold(body: Center(child: Text('Could not load profile.')));

    final account = _data!['account'];
    final farm = _data!['farmer_profile'] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())).then((_) => _load()),
          ),
          const LogoutButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  (account['full_name'] as String? ?? '?').substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 28, color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(child: Text(account['full_name'] ?? '', style: Theme.of(context).textTheme.headlineMedium)),
            Center(child: Text(account['email'] ?? '', style: Theme.of(context).textTheme.bodyMedium)),
            const SizedBox(height: 24),

            _SectionCard(title: 'Personal Details', children: [
              _InfoLine('Phone', account['phone'] ?? '-'),
              _InfoLine('National ID', farm['national_id'] ?? 'Not set'),
              _InfoLine('Date of Birth', farm['date_of_birth'] ?? 'Not set'),
              _InfoLine('Gender', farm['gender'] ?? 'Not set'),
              _InfoLine('Address', farm['address'] ?? 'Not set'),
              _InfoLine('County', farm['county'] ?? 'Not set'),
              _InfoLine('Branch', account['branch_name'] ?? 'Not set'),
            ]),
            const SizedBox(height: 16),
            _SectionCard(title: 'Farming & Livestock Information', children: [
              _InfoLine('Farming Focus', farm['farming_type'] ?? 'Mixed Farming'),
              _InfoLine('Farm Location', farm['farm_location'] ?? 'Not set'),
              _InfoLine('Farm Size', farm['farm_size_acres'] != null ? '${farm['farm_size_acres']} acres' : 'Not set'),
              _InfoLine('Primary Crop', farm['primary_crop'] ?? 'Not set'),
              _InfoLine('Livestock Kept', farm['livestock_type'] ?? 'Not set'),
              _InfoLine('Headcount', farm['livestock_count']?.toString() ?? 'Not set'),
              _InfoLine('Years Farming', farm['years_farming']?.toString() ?? 'Not set'),
              _InfoLine('Has Collateral', farm['has_collateral'] == true ? 'Yes' : 'No'),
            ]),
            if (_advice.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Farming & Livestock Advice',
                children: _advice.map<Widget>((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.goldDark),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a['crop'] ?? 'Advisory',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                ),
                                const SizedBox(height: 2),
                                Text(a['advice'] ?? '', style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: AppColors.danger),
              label: const Text('Log Out', style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
