import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../utils/validators.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nationalIdCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _countyCtrl = TextEditingController();
  final _farmLocationCtrl = TextEditingController();
  final _farmSizeCtrl = TextEditingController();
  final _primaryCropCtrl = TextEditingController();
  final _livestockTypeCtrl = TextEditingController();
  final _livestockCountCtrl = TextEditingController();
  final _yearsFarmingCtrl = TextEditingController();
  String _gender = 'Male';
  String _farmingType = 'Mixed Farming';
  bool _hasCollateral = false;
  DateTime? _dateOfBirth;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.get('/api/profile');
      final account = res['account'];
      final farm = res['farmer_profile'] ?? {};
      _fullNameCtrl.text = account['full_name'] ?? '';
      _phoneCtrl.text = account['phone'] ?? '';
      _nationalIdCtrl.text = farm['national_id'] ?? '';
      _addressCtrl.text = farm['address'] ?? '';
      _countyCtrl.text = farm['county'] ?? '';
      _farmLocationCtrl.text = farm['farm_location'] ?? '';
      _farmSizeCtrl.text = farm['farm_size_acres']?.toString() ?? '';
      _farmingType = farm['farming_type'] ?? 'Mixed Farming';
      _primaryCropCtrl.text = farm['primary_crop'] ?? '';
      _livestockTypeCtrl.text = farm['livestock_type'] ?? '';
      _livestockCountCtrl.text = farm['livestock_count']?.toString() ?? '';
      _yearsFarmingCtrl.text = farm['years_farming']?.toString() ?? '';
      _gender = farm['gender'] ?? 'Male';
      _hasCollateral = farm['has_collateral'] == true;
      if (farm['date_of_birth'] != null) {
        _dateOfBirth = DateTime.tryParse(farm['date_of_birth']);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Select Date of Birth',
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService.put('/api/profile', body: {
        'full_name': _fullNameCtrl.text.trim().isNotEmpty ? _fullNameCtrl.text.trim() : null,
        'phone': normalizeKenyanPhone(_phoneCtrl.text.trim()),
        'national_id': _nationalIdCtrl.text.trim().isEmpty ? null : _nationalIdCtrl.text.trim(),
        'date_of_birth': _dateOfBirth != null ? DateFormat('yyyy-MM-dd').format(_dateOfBirth!) : null,
        'gender': _gender,
        'address': _addressCtrl.text.trim(),
        'county': _countyCtrl.text.trim(),
        'farm_location': _farmLocationCtrl.text.trim(),
        'farm_size_acres': double.tryParse(_farmSizeCtrl.text),
        'farming_type': _farmingType,
        'primary_crop': _primaryCropCtrl.text.trim(),
        'livestock_type': _livestockTypeCtrl.text.trim(),
        'livestock_count': int.tryParse(_livestockCountCtrl.text),
        'years_farming': int.tryParse(_yearsFarmingCtrl.text),
        'has_collateral': _hasCollateral,
      });
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
              Text('Personal Details', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullNameCtrl,
                textCapitalization: TextCapitalization.words,
                inputFormatters: const [CapitalizeWordsInputFormatter()],
                decoration: const InputDecoration(labelText: 'Full Name', hintText: 'e.g. John Kamau'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number', hintText: 'e.g. 0712345678'),
                validator: validateKenyanPhone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nationalIdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'National ID', hintText: '7 or 8 digits'),
                validator: validateNationalId,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDateOfBirth,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date of Birth', suffixIcon: Icon(Icons.calendar_today_outlined)),
                  child: Text(
                    _dateOfBirth != null ? DateFormat.yMMMd().format(_dateOfBirth!) : 'Select date of birth',
                    style: TextStyle(color: _dateOfBirth != null ? null : Theme.of(context).hintColor),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _gender = v ?? 'Male'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                textCapitalization: TextCapitalization.words,
                inputFormatters: const [CapitalizeWordsInputFormatter()],
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _countyCtrl,
                textCapitalization: TextCapitalization.words,
                inputFormatters: const [CapitalizeWordsInputFormatter()],
                decoration: const InputDecoration(labelText: 'County'),
              ),
              const SizedBox(height: 28),
              Text('Farming & Livestock Information', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _farmingType,
                decoration: const InputDecoration(labelText: 'Farming Focus'),
                items: const [
                  DropdownMenuItem(value: 'Crops', child: Text('Crops Only (Maize, Coffee, Tea, etc.)')),
                  DropdownMenuItem(value: 'Livestock', child: Text('Livestock Only (Dairy, Cattle, Poultry, practical)')),
                  DropdownMenuItem(value: 'Mixed Farming', child: Text('Mixed Farming (Crops & Livestock)')),
                ],
                onChanged: (v) => setState(() => _farmingType = v ?? 'Mixed Farming'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _farmLocationCtrl,
                textCapitalization: TextCapitalization.words,
                inputFormatters: const [CapitalizeWordsInputFormatter()],
                decoration: const InputDecoration(labelText: 'Farm Location'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _farmSizeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Farm Size (acres)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _primaryCropCtrl,
                textCapitalization: TextCapitalization.words,
                inputFormatters: const [CapitalizeWordsInputFormatter()],
                decoration: InputDecoration(
                  labelText: _farmingType == 'Livestock'
                      ? 'Primary Crop / Farm Product (Optional for Livestock)'
                      : 'Primary Crop (e.g. Maize, Coffee, Tea, Beans)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _livestockTypeCtrl,
                textCapitalization: TextCapitalization.words,
                inputFormatters: const [CapitalizeWordsInputFormatter()],
                decoration: const InputDecoration(labelText: 'Livestock Kept (e.g. Dairy Cattle, Poultry, Goats)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _livestockCountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Livestock Headcount (e.g. 5 cows, 200 chickens)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _yearsFarmingCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Years Farming'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('I have collateral available'),
                value: _hasCollateral,
                onChanged: (v) => setState(() => _hasCollateral = v),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
