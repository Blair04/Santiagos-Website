import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  static const Color _cream = Color(0xFFF7F4F1);
  static const Color _background = Color(0xFFD8C9BC);
  static const Color _darkBrown = Color(0xFF4B3525);
  static const Color _labelBrown = Color(0xFF5C4635);
  static const Color _accent = Color(0xFFE4CFB3);

  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _showPasswords = false;

  bool get _isStrongPassword {
    final p = _passwordController.text;
    return p.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(p) &&
        RegExp(r'[a-z]').hasMatch(p) &&
        RegExp(r'[0-9]').hasMatch(p) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/~;]').hasMatch(p);
  }

  Future<void> _handleSave() async {
    final password = _passwordController.text;
    final confirmation = _confirmController.text;

    if (!_isStrongPassword) {
      _showSnackBar(
        'Password needs 8+ characters with uppercase, lowercase, a number and a special character.',
        Colors.orangeAccent,
      );
      return;
    }
    if (password != confirmation) {
      _showSnackBar('Passwords do not match.', Colors.orangeAccent);
      return;
    }

    final user = _supabase.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      _showSnackBar('Session expired. Please request a new code.', Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _supabase.auth.updateUser(UserAttributes(password: password));

      var mirrored = true;
      try {
        final updated = await _supabase
            .from('managers')
            .update({'password': password})
            .eq('email', email)
            .select();
        mirrored = updated.isNotEmpty;
      } catch (_) {
        mirrored = false;
      }

      await _supabase.auth.signOut();

      if (!mounted) return;
      _showSnackBar(
        mirrored
            ? 'Password updated. Please log in.'
            : 'Password updated in Auth, but the managers table was not updated (check its policies).',
        mirrored ? Colors.green : Colors.orangeAccent,
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (error) {
      _showSnackBar(error.message, Colors.redAccent);
    } catch (error) {
      _showSnackBar('Something went wrong. Please try again.', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint, double hintSize, double vPadding, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: hintSize),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: vPadding),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black87, width: 1.3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        elevation: 0,
        automaticallyImplyLeading: false,
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
            final double helperSize = isWeb ? 13 : (isTablet ? 12 : 11);
            final double fieldVPadding = isWeb ? 18 : 14;
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
                        color: _background,
                        borderRadius: BorderRadius.circular(radius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(Icons.lock_reset, size: iconSize, color: _labelBrown),
                          SizedBox(height: isWeb ? 16 : 12),
                          Text(
                            'Set New Password',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.bold,
                              color: _darkBrown,
                            ),
                          ),
                          SizedBox(height: isWeb ? 10 : 6),
                          Text(
                            'Choose a strong password for your manager account.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: subtitleSize, color: Colors.black54),
                          ),
                          SizedBox(height: isWeb ? 28 : 20),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_showPasswords,
                            textInputAction: TextInputAction.next,
                            style: TextStyle(fontSize: inputSize),
                            decoration: _decoration(
                              'New password',
                              hintSize,
                              fieldVPadding,
                              suffix: IconButton(
                                icon: Icon(
                                  _showPasswords
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: _labelBrown,
                                ),
                                onPressed: () =>
                                    setState(() => _showPasswords = !_showPasswords),
                              ),
                            ),
                          ),
                          SizedBox(height: isWeb ? 18 : 14),
                          TextFormField(
                            controller: _confirmController,
                            obscureText: !_showPasswords,
                            textInputAction: TextInputAction.done,
                            style: TextStyle(fontSize: inputSize),
                            onFieldSubmitted: (_) {
                              if (!_isLoading) _handleSave();
                            },
                            decoration: _decoration('Confirm new password', hintSize, fieldVPadding),
                          ),
                          SizedBox(height: isWeb ? 8 : 6),
                          Text(
                            '8+ characters, uppercase, lowercase, number and special character.',
                            style: TextStyle(fontSize: helperSize, color: Colors.black54),
                          ),
                          SizedBox(height: isWeb ? 24 : 18),
                          SizedBox(
                            height: buttonHeight,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSave,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: _darkBrown,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(_darkBrown),
                                      ),
                                    )
                                  : Text(
                                      'Save Password',
                                      style: TextStyle(
                                        fontSize: buttonTextSize,
                                        fontWeight: FontWeight.w600,
                                      ),
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