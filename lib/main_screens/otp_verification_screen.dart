import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/main_screens/responsive_side_menu.dart';
import 'new_password_screen.dart';

enum OtpPurpose { signup, recovery }

/// Shared screen for entering the 6-digit code Supabase emails out for
/// either a new signup confirmation or a password recovery request.
class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final OtpPurpose purpose;
  final String? fullName; // only used for signup, to save into `managers`

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.purpose,
    this.fullName,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  int _secondsRemaining = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _secondsRemaining = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _handleVerify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showSnackBar('Please enter the 6-digit code.', Colors.orangeAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _supabase.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: widget.purpose == OtpPurpose.signup ? OtpType.signup : OtpType.recovery,
      );

      if (response.session == null) {
        _showSnackBar('Invalid or expired code. Please try again.', Colors.redAccent);
        return;
      }

      if (widget.purpose == OtpPurpose.signup) {
        // Record the manager in our own table and flip the app_state flag
        // so the register screen/link disappears from now on.
        final userId = response.user!.id;
        await _supabase.from('managers').insert({
          'id': userId,
          'email': widget.email,
          'full_name': widget.fullName,
        });
        await _supabase.from('app_state').update({'manager_registered': true}).eq('id', 1);

        if (!mounted) return;
        _showSnackBar('Account verified! Welcome aboard.', Colors.green);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainResponsivePage()),
          (route) => false,
        );
      } else {
        // Recovery: user now has a valid session, let them set a new password.
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const NewPasswordScreen()),
        );
      }
    } on AuthException catch (error) {
      _showSnackBar(error.message, Colors.redAccent);
    } catch (error) {
      _showSnackBar('Something went wrong. Please try again.', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResend() async {
    if (_secondsRemaining > 0) return;

    try {
      if (widget.purpose == OtpPurpose.signup) {
        await _supabase.auth.resend(type: OtpType.signup, email: widget.email);
      } else {
        await _supabase.auth.resetPasswordForEmail(widget.email);
      }
      _showSnackBar('A new code has been sent.', Colors.green);
      _startResendTimer();
    } catch (_) {
      _showSnackBar('Could not resend code. Try again shortly.', Colors.redAccent);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F4F1),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF5C4635)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: 340,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFD8C9BC),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.mark_email_read_outlined, size: 44, color: Color(0xFF5C4635)),
                const SizedBox(height: 12),
                const Text(
                  'Enter Verification Code',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF4B3525)),
                ),
                const SizedBox(height: 6),
                Text(
                  'We sent a 6-digit code to ${widget.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.black.withOpacity(0.25))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black87, width: 1.3)),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE4CFB3),
                      foregroundColor: const Color(0xFF4B3525),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4B3525))))
                        : const Text('Verify', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _secondsRemaining == 0 ? _handleResend : null,
                    child: Text(
                      _secondsRemaining == 0 ? 'Resend code' : 'Resend code in ${_secondsRemaining}s',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF5C4635), fontWeight: FontWeight.w600),
                    ),
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