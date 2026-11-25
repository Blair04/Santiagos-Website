import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  double get _screenWidth => MediaQuery.of(context).size.width;
  bool get _isTablet => _screenWidth >= 600;
  bool get _isDesktop => _screenWidth >= 1024;

  double get _pagePadding => _isDesktop ? 32 : (_isTablet ? 22 : 14);
  double get _cardPadding => _isDesktop ? 32 : (_isTablet ? 28 : 18);
  double get _cardMaxWidth => _isDesktop ? 520 : (_isTablet ? 480 : 460);
  double get _titleSize => _isDesktop ? 24 : (_isTablet ? 22 : 19);
  double get _heroIconSize => _isTablet ? 48 : 40;
  double get _bodySize => _isTablet ? 13 : 12;
  double get _buttonHeight => _isTablet ? 50 : 46;
  double get _codeFontSize => _isDesktop ? 28 : (_isTablet ? 25 : 22);
  double get _codeSpacing => _isDesktop ? 10 : (_isTablet ? 9 : 6);

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
        title: Text('Change Email Address', style: TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: _isTablet ? 18 : 16)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(_pagePadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _cardMaxWidth),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(_cardPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_isTablet ? 18 : 16),
                  border: Border.all(color: const Color(0xFFE7DED5)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 22, offset: const Offset(0, 8))],
                ),
                child: _isComplete ? _buildSuccess() : _buildVerification(),
              ),
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
            Container(width: _isTablet ? 48 : 34, height: 2, color: isOldEmail ? const Color(0xFFE5DCD3) : _sage),
            _stepIndicator(2, active: !isOldEmail, complete: false),
          ],
        ),
        SizedBox(height: _isTablet ? 26 : 20),
        Icon(isOldEmail ? Icons.mark_email_read_outlined : Icons.verified_user_outlined, size: _heroIconSize, color: _darkBrown),
        const SizedBox(height: 16),
        Text(
          isOldEmail ? 'Verify Current Email' : 'Verify New Email',
          textAlign: TextAlign.center,
          style: TextStyle(color: _ink, fontSize: _titleSize, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 9),
        Text(
          isOldEmail
              ? 'Enter the 6-digit code sent to your currently registered email address.'
              : 'Your current email is verified. Enter the code sent to your new email address to finish the change.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700, fontSize: _bodySize, height: 1.5),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(color: const Color(0xFFF7F3EE), borderRadius: BorderRadius.circular(10)),
          child: Text(_targetEmail, textAlign: TextAlign.center, style: TextStyle(color: _darkBrown, fontWeight: FontWeight.w700, fontSize: _bodySize)),
        ),
        SizedBox(height: _isTablet ? 22 : 18),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          onSubmitted: (_) => _isVerifying ? null : _verifyCode(),
          style: TextStyle(color: _ink, fontSize: _codeFontSize, letterSpacing: _codeSpacing, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            counterText: '',
            hintText: '------',
            filled: true,
            fillColor: const Color(0xFFFAF8F5),
            contentPadding: EdgeInsets.symmetric(vertical: _isTablet ? 17 : 14),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFE0D6CC)),),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _darkBrown, width: 1.5)),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: _buttonHeight,
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
            textAlign: TextAlign.center,
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
    final double size = _isTablet ? 31 : 28;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_rounded, size: _isTablet ? 64 : 52, color: _sage),
        const SizedBox(height: 18),
        Text('Email Successfully Changed', textAlign: TextAlign.center, style: TextStyle(color: _ink, fontSize: _titleSize, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(_completionMessage ?? 'Your login email has been updated.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, fontSize: _bodySize, height: 1.5)),
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
        SizedBox(height: _isTablet ? 22 : 18),
        SizedBox(
          width: double.infinity,
          height: _buttonHeight,
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