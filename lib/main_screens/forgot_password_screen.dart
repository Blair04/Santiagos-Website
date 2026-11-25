import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'otp_verification_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;

  Future<void> _handleSendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('Please enter your email.', Colors.orangeAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final existing = await _supabase.from('managers').select('email').eq('email', email).maybeSingle();

      if (existing == null) {
        _showSnackBar('No manager account found for that email.', Colors.redAccent);
        return;
      }

      await _supabase.auth.resetPasswordForEmail(email);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(email: email, purpose: OtpPurpose.recovery),
        ),
      );
    } on AuthException catch (error) {
      _showSnackBar(error.message, Colors.redAccent);
    } catch (error) {
      _showSnackBar('Network communication error.', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    _emailController.dispose();
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
            final double inputSize = isWeb ? 16 : (isTablet ? 15 : 14);
            final double hintSize = isWeb ? 15 : (isTablet ? 14 : 13);
            final double buttonHeight = isWeb ? 52 : (isTablet ? 50 : 46);
            final double buttonTextSize = isWeb ? 17 : (isTablet ? 16 : 15);
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
                          Icon(Icons.lock_reset, size: iconSize, color: const Color(0xFF5C4635)),
                          SizedBox(height: isWeb ? 16 : 12),
                          Text(
                            'Reset Password',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold, color: const Color(0xFF4B3525)),
                          ),
                          SizedBox(height: isWeb ? 10 : 6),
                          Text(
                            "Enter your registered manager email and we'll send a 6-digit code.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: subtitleSize, color: Colors.black54),
                          ),
                          SizedBox(height: isWeb ? 28 : 20),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_isLoading) _handleSendCode();
                            },
                            style: TextStyle(fontSize: inputSize),
                            decoration: InputDecoration(
                              hintText: 'example@gmail.com',
                              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: hintSize),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: isWeb ? 18 : 14),
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
                          SizedBox(height: isWeb ? 28 : 20),
                          SizedBox(
                            width: double.infinity,
                            height: buttonHeight,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSendCode,
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
                                  : Text('Send Code', style: TextStyle(fontSize: buttonTextSize, fontWeight: FontWeight.w600)),
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