import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class RepaymentFlowWidget extends StatefulWidget {
  final String loanId;
  final String initialAmount;
  final String initialPhone;
  final VoidCallback onSuccess;

  const RepaymentFlowWidget({
    super.key,
    required this.loanId,
    required this.initialAmount,
    required this.initialPhone,
    required this.onSuccess,
  });

  @override
  State<RepaymentFlowWidget> createState() => _RepaymentFlowWidgetState();
}

enum _Step { form, pending, done }

class _RepaymentFlowWidgetState extends State<RepaymentFlowWidget> {
  late TextEditingController _amountCtrl;
  late TextEditingController _phoneCtrl;
  bool _loading = false;
  String? _error;
  _Step _step = _Step.form;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.initialAmount);
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountText = _amountCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount greater than 0.');
      return;
    }
    if (phone.isEmpty) {
      setState(() => _error = 'Please enter your M-Pesa phone number.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final payload = {
        'amount': amount,
        'phone_number': phone,
        'payment_method': 'M-Pesa',
      };

      final result = await ApiService.post(
        '/api/loans/${widget.loanId}/pay',
        body: payload,
      );

      // Backend returns 202 with stkPushSent: true when the STK push is sent.
      // Show a pending screen telling the user to check their phone.
      final stkSent = result is Map && result['stkPushSent'] == true;
      final checkoutId =
          result is Map ? result['checkoutRequestId'] as String? : null;
      if (mounted) {
        setState(() => _step = stkSent ? _Step.pending : _Step.done);
        if (stkSent && checkoutId != null) {
          _startPolling(checkoutId);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startPolling(String checkoutId) {
    _pollTimer?.cancel();
    int count = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      count++;
      if (count > 20) {
        // 40 seconds max poll
        timer.cancel();
        return;
      }
      try {
        final res = await ApiService.get(
            '/api/loans/${widget.loanId}/mpesa/query?checkoutRequestId=$checkoutId');
        if (res is Map) {
          final payment = res['payment'];
          if (payment != null) {
            final status = payment['status'];
            if (status == 'completed') {
              timer.cancel();
              if (mounted) {
                setState(() => _step = _Step.done);
              }
            } else if (status == 'failed') {
              timer.cancel();
              if (mounted) {
                setState(() {
                  _step = _Step.form;
                  _error = 'Repayment failed. Please try again.';
                });
              }
            }
          }
        }
      } catch (e) {
        // Suppress and try again
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E2A22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _step == _Step.pending
              ? _buildPendingView()
              : _step == _Step.done
                  ? _buildDoneView()
                  : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      key: const ValueKey('form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Make Repayment',
          style: GoogleFonts.fraunces(
            fontSize: 22,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'A payment prompt will be sent to your phone.',
          style: GoogleFonts.publicSans(fontSize: 13, color: Colors.white54),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount (KSh)',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixText: 'KSh ',
            prefixStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24),
            ),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'M-Pesa Phone (e.g., 0712345678)',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(Icons.phone_android, color: Colors.white54),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24),
            ),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: GoogleFonts.publicSans(
                        color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.shamba900,
              disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.mobile_friendly, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Pay via M‑Pesa',
                        style: GoogleFonts.publicSans(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingView() {
    return Column(
      key: const ValueKey('pending'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.phone_in_talk_rounded,
              size: 48, color: AppColors.gold),
        ),
        const SizedBox(height: 20),
        Text(
          'Check Your Phone!',
          style: GoogleFonts.fraunces(
              fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'An M-Pesa prompt has been sent to\n${_phoneCtrl.text}.\n\nEnter your PIN to complete the payment.',
          style: GoogleFonts.publicSans(
              fontSize: 14, color: Colors.white70, height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Your loan balance will update automatically once confirmed.',
          style: GoogleFonts.publicSans(fontSize: 12, color: Colors.white38),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              widget.onSuccess();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.shamba900,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Done',
              style: GoogleFonts.publicSans(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() {
            _step = _Step.form;
            _error = null;
          }),
          child: Text(
            'Didn\'t receive a prompt? Try again',
            style: GoogleFonts.publicSans(color: Colors.white54, fontSize: 13),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildDoneView() {
    return Column(
      key: const ValueKey('done'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded,
              size: 52, color: Colors.greenAccent),
        ),
        const SizedBox(height: 20),
        Text(
          'Payment Recorded!',
          style: GoogleFonts.fraunces(
              fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Your repayment has been received successfully.',
          style: GoogleFonts.publicSans(fontSize: 14, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              widget.onSuccess();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Back to My Loans',
              style: GoogleFonts.publicSans(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
