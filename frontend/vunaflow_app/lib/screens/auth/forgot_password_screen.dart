import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/validators.dart';
import '../../widgets/auth_shell.dart';

/// Three-step flow: enter email -> answer the two security questions on
/// file for that account -> set a new password. No email/SMS delivery
/// required, since this build has no provider for that.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 1;
  bool _loading = false;
  String? _error;
  String? _message;

  final _emailCtrl = TextEditingController();
  final _answer1Ctrl = TextEditingController();
  final _answer2Ctrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  String? _question1;
  String? _question2;
  String? _resetToken;

  Future<void> _lookupQuestions() async {
    if (_emailCtrl.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.get('/api/auth/security-questions', query: {'email': _emailCtrl.text.trim()});
      setState(() {
        _question1 = res['question_1'];
        _question2 = res['question_2'];
        _step = 2;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not look up this account. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyAnswers() async {
    if (_answer1Ctrl.text.trim().isEmpty || _answer2Ctrl.text.trim().isEmpty) {
      setState(() => _error = 'Please answer both questions');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.post('/api/auth/verify-security-answers', body: {
        'email': _emailCtrl.text.trim(),
        'answer_1': _answer1Ctrl.text.trim(),
        'answer_2': _answer2Ctrl.text.trim(),
      });
      setState(() {
        _resetToken = res['reset_token'];
        _step = 3;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not verify your answers. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final passwordError = validatePassword(_newPasswordCtrl.text);
    if (passwordError != null) {
      setState(() => _error = passwordError);
      return;
    }
    final confirmError = validateConfirmPassword(_confirmPasswordCtrl.text, _newPasswordCtrl.text);
    if (confirmError != null) {
      setState(() => _error = confirmError);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiService.post('/api/auth/reset-password', body: {
        'email': _emailCtrl.text.trim(),
        'reset_token': _resetToken,
        'new_password': _newPasswordCtrl.text,
      });
      setState(() {
        _message = 'Password reset successfully. You can now log in with your new password.';
        _step = 4;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Forgot Password',
      subtitle: _subtitleForStep(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ),
            const SizedBox(height: 16),
          ],
          if (_message != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
              child: Text(_message!, style: TextStyle(color: Colors.green.shade800)),
            ),
            const SizedBox(height: 16),
          ],
          if (_step == 1) ..._buildStep1(),
          if (_step == 2) ..._buildStep2(),
          if (_step == 3) ..._buildStep3(),
          if (_step == 4) ..._buildStep4(),
        ],
      ),
    );
  }

  String _subtitleForStep() {
    switch (_step) {
      case 2:
        return 'Answer your two security questions to verify your identity.';
      case 3:
        return 'Set a new password for your account.';
      case 4:
        return 'All done.';
      default:
        return 'Enter your account email to get started.';
    }
  }

  List<Widget> _buildStep1() {
    return [
      TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _loading ? null : _lookupQuestions,
        child: _loading
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Continue'),
      ),
    ];
  }

  List<Widget> _buildStep2() {
    return [
      Text(_question1 ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextField(controller: _answer1Ctrl, decoration: const InputDecoration(labelText: 'Your Answer')),
      const SizedBox(height: 20),
      Text(_question2 ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextField(controller: _answer2Ctrl, decoration: const InputDecoration(labelText: 'Your Answer')),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _loading ? null : _verifyAnswers,
        child: _loading
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Verify Answers'),
      ),
    ];
  }

  List<Widget> _buildStep3() {
    return [
      TextField(
        controller: _newPasswordCtrl,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'New Password', hintText: 'At least 8 characters', prefixIcon: Icon(Icons.lock_outline)),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _confirmPasswordCtrl,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Confirm New Password', prefixIcon: Icon(Icons.lock_outline)),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _loading ? null : _resetPassword,
        child: _loading
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Reset Password'),
      ),
    ];
  }

  List<Widget> _buildStep4() {
    return [
      ElevatedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back to Login'),
      ),
    ];
  }
}
