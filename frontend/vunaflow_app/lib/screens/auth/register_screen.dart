import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/vunaflow_logo.dart';
import '../client/client_dashboard_screen.dart';
import 'client_login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _answer1Ctrl = TextEditingController();
  final _answer2Ctrl = TextEditingController();

  List<dynamic> _branches = [];
  String? _selectedBranchId;
  List<dynamic> _securityQuestions = [];
  String? _question1;
  String? _question2;

  bool _loading = false;
  bool _loadingBranches = true;
  bool _loadingQuestions = true;
  bool _branchesFailed = false;
  bool _questionsFailed = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;

  int _activeStep = 0; // 0 = Account & Branch, 1 = Security Questions

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _loadSecurityQuestions();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _loadingBranches = true;
      _branchesFailed = false;
    });
    try {
      final res = await ApiService.get('/api/branches');
      setState(() => _branches = res as List<dynamic>);
    } catch (_) {
      setState(() => _branchesFailed = true);
    } finally {
      if (mounted) setState(() => _loadingBranches = false);
    }
  }

  Future<void> _loadSecurityQuestions() async {
    setState(() {
      _loadingQuestions = true;
      _questionsFailed = false;
    });
    try {
      final res = await ApiService.get('/api/auth/security-question-options');
      setState(() => _securityQuestions = res as List<dynamic>);
    } catch (_) {
      setState(() => _questionsFailed = true);
    } finally {
      if (mounted) setState(() => _loadingQuestions = false);
    }
  }

  String _capitalizeWords(String input) {
    if (input.trim().isEmpty) return input.trim();
    return input.trim().split(RegExp(r'\s+')).map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : '');
    }).join(' ');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_question1 == null || _question2 == null) {
      setState(() => _error = 'Please select two security questions');
      return;
    }
    if (_question1 == _question2) {
      setState(() => _error = 'Please choose two different security questions');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().register(
            fullName: _capitalizeWords(_nameCtrl.text),
            email: _emailCtrl.text.trim(),
            phone: normalizeKenyanPhone(_phoneCtrl.text.trim()),
            password: _passwordCtrl.text,
            confirmPassword: _confirmPasswordCtrl.text,
            securityQuestion1: _question1!,
            securityAnswer1: _answer1Ctrl.text.trim(),
            securityQuestion2: _question2!,
            securityAnswer2: _answer2Ctrl.text.trim(),
            branchId: _selectedBranchId,
          );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ClientDashboardScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 960;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1140),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 40,
                  vertical: isMobile ? 24 : 48,
                ),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBrandHeader(),
                          const SizedBox(height: 24),
                          _buildFormCard(),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 10, child: _buildBrandSidePanel()),
                          const SizedBox(width: 48),
                          Expanded(flex: 12, child: _buildFormCard()),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const VunaFlowLogo(size: 36, showWordmark: true),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(
                'Back to home',
                style: GoogleFonts.publicSans(color: AppColors.inkSoft, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Create Your Account',
          style: GoogleFonts.fraunces(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Register as a farmer to apply for AFC loans through VunaFlow.',
          style: GoogleFonts.publicSans(fontSize: 15, color: AppColors.inkSoft),
        ),
      ],
    );
  }

  Widget _buildBrandSidePanel() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.shamba800, AppColors.shamba900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(18, 35, 24, 0.2),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const VunaFlowLogo(size: 38, showWordmark: false),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: AppColors.goldPale),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x1AF5F2E7),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: const Color(0x38F5F2E7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.spa_outlined, color: AppColors.goldPale, size: 15),
                const SizedBox(width: 8),
                Text(
                  'FARMER ONBOARDING',
                  style: GoogleFonts.publicSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldPale,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          RichText(
            text: TextSpan(
              style: GoogleFonts.fraunces(
                color: AppColors.parchment,
                fontSize: 38,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
              children: [
                const TextSpan(text: 'Plant your credit\njourney '),
                TextSpan(
                  text: 'today.',
                  style: GoogleFonts.fraunces(
                    fontStyle: FontStyle.italic,
                    color: AppColors.goldPale,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Join thousands of Kenyan farmers accessing flexible agricultural credit across AFC\'s 43 branches nationwide.',
            style: GoogleFonts.publicSans(
              fontSize: 15.5,
              height: 1.6,
              color: const Color(0xD1F5F2E7),
            ),
          ),
          const SizedBox(height: 44),
          const Divider(color: AppColors.lineOnDark),
          const SizedBox(height: 24),
          _buildTrustFeature(Icons.flash_on_outlined, 'Fast & Guided Application', 'Step-by-step guidance from form to disbursement'),
          const SizedBox(height: 18),
          _buildTrustFeature(Icons.security_outlined, 'Passwordless Reset Security', 'Security questions protect your account without SMS/email delays'),
          const SizedBox(height: 18),
          _buildTrustFeature(Icons.storefront_outlined, '43 AFC Branch Network', 'Connect directly to your local branch officer'),
        ],
      ),
    );
  }

  Widget _buildTrustFeature(IconData icon, String title, String sub) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0x18F5F2E7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.goldPale, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.publicSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.parchment,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: GoogleFonts.publicSans(
                  fontSize: 12.5,
                  color: const Color(0xB3F5F2E7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(34, 36, 30, 0.04),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color.fromRGBO(34, 36, 30, 0.06),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Step Progress Tab Switcher
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeStep = 0),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _activeStep == 0 ? AppColors.shamba700 : AppColors.line,
                            width: _activeStep == 0 ? 2.5 : 1,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '1. Personal Info',
                          style: GoogleFonts.publicSans(
                            fontSize: 14,
                            fontWeight: _activeStep == 0 ? FontWeight.w700 : FontWeight.w500,
                            color: _activeStep == 0 ? AppColors.shamba700 : AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_formKey.currentState!.validate()) {
                        setState(() => _activeStep = 1);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _activeStep == 1 ? AppColors.shamba700 : AppColors.line,
                            width: _activeStep == 1 ? 2.5 : 1,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '2. Security Questions',
                          style: GoogleFonts.publicSans(
                            fontSize: 14,
                            fontWeight: _activeStep == 1 ? FontWeight.w700 : FontWeight.w500,
                            color: _activeStep == 1 ? AppColors.shamba700 : AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6E3DF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brick),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.brick, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.publicSans(
                          color: AppColors.brick,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_activeStep == 0) ..._buildStep1Fields() else ..._buildStep2Fields(),

            const SizedBox(height: 28),
            Row(
              children: [
                if (_activeStep == 1) ...[
                  OutlinedButton(
                    onPressed: () => setState(() => _activeStep = 0),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () {
                            if (_activeStep == 0) {
                              if (_formKey.currentState!.validate()) {
                                setState(() => _activeStep = 1);
                              }
                            } else {
                              _submit();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.ink,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                          )
                        : Text(
                            _activeStep == 0 ? 'Continue to Security →' : 'Create Account & Start Loan',
                            style: GoogleFonts.publicSans(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: GoogleFonts.publicSans(fontSize: 14, color: AppColors.inkSoft),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ClientLoginScreen()),
                      );
                    },
                    child: Text(
                      'Log in',
                      style: GoogleFonts.publicSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.shamba700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStep1Fields() {
    return [
      TextFormField(
        controller: _nameCtrl,
        textCapitalization: TextCapitalization.words,
        inputFormatters: const [CapitalizeWordsInputFormatter()],
        decoration: const InputDecoration(
          labelText: 'Full Name',
          prefixIcon: Icon(Icons.person_outline, color: AppColors.shamba700),
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Email Address',
          prefixIcon: Icon(Icons.email_outlined, color: AppColors.shamba700),
        ),
        validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Phone Number',
          hintText: 'e.g. 0712345678 or +254712345678',
          prefixIcon: Icon(Icons.phone_outlined, color: AppColors.shamba700),
        ),
        validator: validateKenyanPhone,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _passwordCtrl,
        obscureText: _obscure,
        decoration: InputDecoration(
          labelText: 'Password',
          hintText: 'At least 8 characters',
          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.shamba700),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        validator: validatePassword,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _confirmPasswordCtrl,
        obscureText: _obscureConfirm,
        decoration: InputDecoration(
          labelText: 'Confirm Password',
          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.shamba700),
          suffixIcon: IconButton(
            icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        validator: (v) => validateConfirmPassword(v, _passwordCtrl.text),
      ),
      const SizedBox(height: 16),
      _loadingBranches
          ? const LinearProgressIndicator()
          : _branchesFailed
              ? Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF6E3DF), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Could not load AFC branches.',
                          style: GoogleFonts.publicSans(color: AppColors.brick, fontSize: 13),
                        ),
                      ),
                      TextButton(onPressed: _loadBranches, child: const Text('Retry')),
                    ],
                  ),
                )
              : DropdownButtonFormField<String>(
                  value: _selectedBranchId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Preferred AFC Branch (optional)',
                    prefixIcon: Icon(Icons.storefront_outlined, color: AppColors.shamba700),
                  ),
                  items: _branches
                      .map<DropdownMenuItem<String>>((b) => DropdownMenuItem(
                            value: b['id'] as String,
                            child: Text(b['name'], overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedBranchId = v),
                ),
    ];
  }

  List<Widget> _buildStep2Fields() {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.parchment2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.shamba700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Security Verification Questions',
                    style: GoogleFonts.fraunces(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Used to verify your identity if you ever forget your password — no email or SMS code required.',
              style: GoogleFonts.publicSans(fontSize: 13, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _loadingQuestions
          ? const LinearProgressIndicator()
          : _questionsFailed
              ? Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF6E3DF), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Could not load security questions. Check that the server is running.',
                        style: GoogleFonts.publicSans(color: AppColors.brick, fontSize: 13),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: _loadSecurityQuestions, child: const Text('Retry')),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _question1,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Security Question 1',
                        prefixIcon: Icon(Icons.help_outline, color: AppColors.shamba700),
                      ),
                      items: _securityQuestions
                          .where((q) => q != _question2)
                          .map<DropdownMenuItem<String>>((q) => DropdownMenuItem(
                                value: q as String,
                                child: Text(q, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _question1 = v),
                      validator: (v) => v == null ? 'Select a question' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _answer1Ctrl,
                      decoration: const InputDecoration(
                        labelText: 'Answer 1',
                        prefixIcon: Icon(Icons.edit_note, color: AppColors.shamba700),
                      ),
                      validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your answer' : null,
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      value: _question2,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Security Question 2',
                        prefixIcon: Icon(Icons.help_outline, color: AppColors.shamba700),
                      ),
                      items: _securityQuestions
                          .where((q) => q != _question1)
                          .map<DropdownMenuItem<String>>((q) => DropdownMenuItem(
                                value: q as String,
                                child: Text(q, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _question2 = v),
                      validator: (v) => v == null ? 'Select a question' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _answer2Ctrl,
                      decoration: const InputDecoration(
                        labelText: 'Answer 2',
                        prefixIcon: Icon(Icons.edit_note, color: AppColors.shamba700),
                      ),
                      validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your answer' : null,
                    ),
                  ],
                ),
    ];
  }
}
