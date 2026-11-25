import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/main_screens/responsive_side_menu.dart';
import 'new_password_screen.dart';

enum OtpPurpose { signup, recovery }

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final OtpPurpose purpose;
  final String? fullName;

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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final bool isWeb = width >= 1024;
            final bool isTablet = width >= 600 && width < 1024;

            final double cardMaxWidth = isWeb ? 460 : (isTablet ? 420 : 360);
            final double outerPadding = isWeb ? 32 : (isTablet ? 28 : 16);
            final double innerHPadding = isWeb ? 32 : (isTablet ? 28 : 22);
            final double innerVPadding = isWeb ? 36 : (isTablet ? 32 : 24);
            final double iconSize = isWeb ? 60 : (isTablet ? 54 : 44);
            final double titleSize = isWeb ? 22 : (isTablet ? 20 : 17);
            final double subtitleSize = isWeb ? 14 : (isTablet ? 13.5 : 12);
            final double codeSize = isWeb ? 28 : (isTablet ? 26 : 22);
            final double codeSpacing = isWeb ? 10 : (isTablet ? 9 : 8);
            final double fieldVPadding = isWeb ? 18 : 14;
            final double buttonHeight = isWeb ? 52 : (isTablet ? 50 : 46);
            final double buttonTextSize = isWeb ? 17 : (isTablet ? 16 : 15);
            final double resendSize = isWeb ? 14 : (isTablet ? 13 : 12);
            final double radius = isWeb ? 22 : 18;

            return SingleChildScrollView(
              padding: EdgeInsets.all(outerPadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (outerPadding * 2),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardMaxWidth),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: innerHPadding, vertical: innerVPadding),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8C9BC),
                        borderRadius: BorderRadius.circular(radius),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(Icons.mark_email_read_outlined, size: iconSize, color: const Color(0xFF5C4635)),
                          SizedBox(height: isWeb ? 16 : 12),
                          Text(
                            'Enter Verification Code',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold, color: const Color(0xFF4B3525)),
                          ),
                          SizedBox(height: isWeb ? 10 : 6),
                          Text(
                            'We sent a 6-digit code to ${widget.email}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: subtitleSize, color: Colors.black54),
                          ),
                          SizedBox(height: isWeb ? 28 : 22),
                          TextFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            onFieldSubmitted: (_) {
                              if (!_isLoading) _handleVerify();
                            },
                            style: TextStyle(fontSize: codeSize, letterSpacing: codeSpacing, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(vertical: fieldVPadding),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.black.withOpacity(0.25)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.black87, width: 1.3),
                              ),
                            ),
                          ),
                          SizedBox(height: isWeb ? 24 : 18),
                          SizedBox(
                            width: double.infinity,
                            height: buttonHeight,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleVerify,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE4CFB3),
                                foregroundColor: const Color(0xFF4B3525),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4B3525)),
                                      ),
                                    )
                                  : Text('Verify', style: TextStyle(fontSize: buttonTextSize, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          SizedBox(height: isWeb ? 16 : 12),
                          Center(
                            child: TextButton(
                              onPressed: _secondsRemaining == 0 ? _handleResend : null,
                              child: Text(
                                _secondsRemaining == 0 ? 'Resend code' : 'Resend code in ${_secondsRemaining}s',
                                style: TextStyle(fontSize: resendSize, color: const Color(0xFF5C4635), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}