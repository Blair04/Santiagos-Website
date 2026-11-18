import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Two-stage OTP verification for a secure Supabase email change.
/// Secure Email Change must remain enabled in the Supabase Email provider.
class EmailChangeOtpScreen extends StatefulWidget {
  final String oldEmail;
  final String newEmail;
  final String userId;

  const EmailChangeOtpScreen({
    super.key,
    required this.oldEmail,
    required this.newEmail,
    required this.userId,
  });

  @override
  State<EmailChangeOtpScreen> createState() => _EmailChangeOtpScreenState();
}

class _EmailChangeOtpScreenState extends State<EmailChangeOtpScreen> {
  static const Color _background = Color(0xFFF9F6F0);
  static const Color _ink = Color(0xFF2C2221);
  static const Color _darkBrown = Color(0xFF6D4C41);
  static const Color _sage = Color(0xFF438A5E);
  static const Color _mutedRed = Color(0xFFD9534F);

  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _codeController = TextEditingController();
  Timer? _resendTimer;
  int _secondsRemaining = 60;
  int _step = 0;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _isComplete = false;
  String? _completionMessage;

  String get _targetEmail => _step == 0 ? widget.oldEmail : widget.newEmail;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _secondsRemaining = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showMessage('Enter the complete 6-digit verification code.', _mutedRed);
      return;
    }

    setState(() => _isVerifying = true);
    try {
      final response = await _supabase.auth.verifyOTP(
        email: _targetEmail,
        token: code,
        type: OtpType.emailChange,
      );

      if (_step == 0) {
        // With Secure Email Change enabled, Supabase accepts the first OTP
        // as an intermediate verification. The second OTP completes the change.
        _codeController.clear();
        setState(() => _step = 1);
        _startResendTimer();
        _showMessage('Current email verified. Now verify your new email.', _sage);
        return;
      }

      if (response.session == null || response.user?.id != widget.userId) {
        _showMessage('The email change is not complete yet. Check the code and try again.', _mutedRed);
        return;
      }

      // Supabase Auth is the source of truth. Mirror the new email to the
      // manager profile only after both OTPs have been accepted.
      var profileSynced = true;
      try {
        await _supabase
            .from('managers')
            .update({'email': widget.newEmail})
            .eq('id', widget.userId);
      } catch (_) {
        profileSynced = false;
      }

      if (!mounted) return;
      setState(() {
        _isComplete = true;
        _completionMessage = profileSynced
            ? 'Your login email has been successfully changed.'
            : 'Your login email was changed in Supabase Auth, but the manager profile could not be synchronized. Please contact the administrator.';
      });
    } on AuthException catch (error) {
      _showMessage(error.message, _mutedRed);
    } catch (_) {
      _showMessage('Verification failed. Please check your connection and try again.', _mutedRed);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendCodes() async {
    if (_secondsRemaining > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      // Supabase resends the pending email-change verification email(s).
      await _supabase.auth.resend(
        type: OtpType.emailChange,
        email: widget.newEmail,
      );
      _showMessage('Verification email(s) resent. Check your inbox.', _sage);
      _startResendTimer();
    } on AuthException catch (error) {
      _showMessage(error.message, _mutedRed);
    } catch (_) {
      _showMessage('Could not resend the verification email. Please try again.', _mutedRed);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        iconTheme: const IconThemeData(color: _darkBrown),
        title: const Text('Change Email Address', style: TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE7DED5)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 22, offset: const Offset(0, 8))],
              ),
              child: _isComplete ? _buildSuccess() : _buildVerification(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerification() {
    final isOldEmail = _step == 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _stepIndicator(1, active: true, complete: false),
            Container(width: 48, height: 2, color: isOldEmail ? const Color(0xFFE5DCD3) : _sage),
            _stepIndicator(2, active: !isOldEmail, complete: false),
          ],
        ),
        const SizedBox(height: 26),
        Icon(isOldEmail ? Icons.mark_email_read_outlined : Icons.verified_user_outlined, size: 48, color: _darkBrown),
        const SizedBox(height: 16),
        Text(
          isOldEmail ? 'Verify Current Email' : 'Verify New Email',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 9),
        Text(
          isOldEmail
              ? 'Enter the 6-digit code sent to your currently registered email address.'
              : 'Your current email is verified. Enter the code sent to your new email address to finish the change.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(color: const Color(0xFFF7F3EE), borderRadius: BorderRadius.circular(10)),
          child: Text(_targetEmail, textAlign: TextAlign.center, style: const TextStyle(color: _darkBrown, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _ink, fontSize: 25, letterSpacing: 9, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            counterText: '',
            hintText: '------',
            filled: true,
            fillColor: const Color(0xFFFAF8F5),
            contentPadding: const EdgeInsets.symmetric(vertical: 17),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFE0D6CC)),),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _darkBrown, width: 1.5)),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _isVerifying ? null : _verifyCode,
            style: FilledButton.styleFrom(backgroundColor: _darkBrown, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
            child: _isVerifying
                ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(isOldEmail ? 'Verify Current Email' : 'Verify New Email'),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _secondsRemaining == 0 && !_isResending ? _resendCodes : null,
          child: Text(
            _isResending ? 'Sending...' : _secondsRemaining == 0 ? 'Resend verification email(s)' : 'Resend available in ${_secondsRemaining}s',
            style: const TextStyle(color: _darkBrown, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
        const SizedBox(height: 5),
        Text('Never share your verification code with anyone.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ],
    );
  }

  Widget _stepIndicator(int number, {required bool active, required bool complete}) {
    final color = complete || active ? _sage : const Color(0xFFD8CEC4);
    return Container(
      width: 31,
      height: 31,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, size: 64, color: _sage),
        const SizedBox(height: 18),
        const Text('Email Successfully Changed', textAlign: TextAlign.center, style: TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(_completionMessage ?? 'Your login email has been updated.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.5)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: const Color(0xFFF7F3EE), borderRadius: BorderRadius.circular(10)),
          child: Column(
            children: [
              Text('New login email', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
              const SizedBox(height: 5),
              Text(widget.newEmail, textAlign: TextAlign.center, style: const TextStyle(color: _darkBrown, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(backgroundColor: _darkBrown, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
            child: const Text('Back to Account Settings'),
          ),
        ),
      ],
    );
  }
}
