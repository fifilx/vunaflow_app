import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/logout_button.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../utils/validators.dart';

class StaffAdminTab extends StatelessWidget {
  const StaffAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          actions: const [ThemeToggleButton(), LogoutButton()],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Staff & Roles'),
              Tab(text: 'Branches'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _StaffRolesView(),
            _ManageBranchesView(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Staff & Roles
// ---------------------------------------------------------------------------
class _StaffRolesView extends StatefulWidget {
  const _StaffRolesView();

  @override
  State<_StaffRolesView> createState() => _StaffRolesViewState();
}

class _StaffRolesViewState extends State<_StaffRolesView> {
  bool _loading = true;
  List<dynamic> _staff = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/api/admin/staff');
      setState(() => _staff = res as List<dynamic>);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> staff) async {
    final isActive = staff['is_active'] == true;
    try {
      await ApiService.patch('/api/admin/staff/${staff['id']}/${isActive ? 'disable' : 'enable'}');
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _changeRole(Map<String, dynamic> staff) async {
    final newRole = staff['role'] == 'admin' ? 'staff' : 'admin';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Role'),
        content: Text('Assign "${staff['full_name']}" the role of $newRole?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.patch('/api/admin/staff/${staff['id']}/role', body: {'role': newRole});
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openAddStaffDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final employeeNoCtrl = TextEditingController();
    final departmentCtrl = TextEditingController();
    String role = 'staff';
    String? error;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Staff Member'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error!, style: const TextStyle(color: Colors.red))),
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: const [CapitalizeWordsInputFormatter()],
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => v!.contains('@') ? null : 'Invalid email'),
                  const SizedBox(height: 10),
                  TextFormField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', hintText: 'e.g. 0712345678'), validator: validateKenyanPhone),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Temporary Password', hintText: 'At least 8 characters'),
                    validator: validatePassword,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(controller: employeeNoCtrl, decoration: const InputDecoration(labelText: 'Employee No. (optional)')),
                  const SizedBox(height: 10),
                  TextFormField(controller: departmentCtrl, decoration: const InputDecoration(labelText: 'Department (optional)')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (v) => setDialogState(() => role = v ?? 'staff'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await ApiService.post('/api/admin/staff', body: {
                    'full_name': nameCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'phone': normalizeKenyanPhone(phoneCtrl.text.trim()),
                    'password': passwordCtrl.text,
                    'role': role,
                    'employee_no': employeeNoCtrl.text.trim(),
                    'department': departmentCtrl.text.trim(),
                  });
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _load();
                } on ApiException catch (e) {
                  setDialogState(() => error = e.message);
                }
              },
              child: const Text('Add Staff'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin_add_staff_fab',
        onPressed: _openAddStaffDialog,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Staff'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: _staff.isEmpty
                      ? ListView(children: const [Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No staff accounts yet.')))])
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _staff.length,
                          itemBuilder: (context, i) {
                            final s = _staff[i];
                            final isActive = s['is_active'] == true;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(s['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: (isActive ? AppColors.success : AppColors.danger).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(isActive ? 'Active' : 'Disabled', style: TextStyle(color: isActive ? AppColors.success : AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                                        ),
                                      ],
                                    ),
                                    Text(s['email'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
                                    Text('Role: ${s['role']}${s['department'] != null && s['department'] != '' ? ' · ${s['department']}' : ''}', style: Theme.of(context).textTheme.bodyMedium),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        OutlinedButton(onPressed: () => _changeRole(s), child: Text(s['role'] == 'admin' ? 'Make Staff' : 'Make Admin')),
                                        OutlinedButton(
                                          onPressed: () => _toggleStatus(s),
                                          style: OutlinedButton.styleFrom(foregroundColor: isActive ? AppColors.danger : AppColors.success),
                                          child: Text(isActive ? 'Disable' : 'Enable'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Manage Branches
// ---------------------------------------------------------------------------
class _ManageBranchesView extends StatefulWidget {
  const _ManageBranchesView();

  @override
  State<_ManageBranchesView> createState() => _ManageBranchesViewState();
}

class _ManageBranchesViewState extends State<_ManageBranchesView> {
  bool _loading = true;
  List<dynamic> _branches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/api/branches');
      setState(() => _branches = res as List<dynamic>);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAddBranchDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final countyCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add AFC Branch'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error!, style: const TextStyle(color: Colors.red))),
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: const [CapitalizeWordsInputFormatter()],
                    decoration: const InputDecoration(labelText: 'Branch Name'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Branch Code', hintText: 'e.g. KTU-01'), validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 10),
                  TextFormField(controller: countyCtrl, decoration: const InputDecoration(labelText: 'County')),
                  const SizedBox(height: 10),
                  TextFormField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address / Location')),
                  const SizedBox(height: 10),
                  TextFormField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone (optional)')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await ApiService.post('/api/branches', body: {
                    'name': nameCtrl.text.trim(),
                    'code': codeCtrl.text.trim(),
                    'county': countyCtrl.text.trim(),
                    'address': addressCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                  });
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _load();
                } on ApiException catch (e) {
                  setDialogState(() => error = e.message);
                }
              },
              child: const Text('Add Branch'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin_add_branch_fab',
        onPressed: _openAddBranchDialog,
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Add Branch'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('${_branches.length} branches on file', style: Theme.of(context).textTheme.bodyMedium),
                        ),
                      ),
                      Expanded(
                        child: _branches.isEmpty
                            ? ListView(children: const [Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No branches yet.')))])
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                                itemCount: _branches.length,
                                itemBuilder: (context, i) {
                                  final b = _branches[i];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: const Icon(Icons.store_outlined, color: AppColors.primary),
                                      title: Text(b['name'] ?? ''),
                                      subtitle: Text('${b['county'] ?? ''} · ${b['address'] ?? ''}'),
                                      trailing: b['phone'] != null ? Text(b['phone'], style: Theme.of(context).textTheme.bodyMedium) : null,
                                    ),
                                  );
                                },
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
