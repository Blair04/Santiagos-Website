import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shown after the recovery code is verified (the user now has a session).
/// Saves the new password in Supabase Auth AND in the `managers` table.
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
      // 1. Change the password in Supabase Auth.
      await _supabase.auth.updateUser(UserAttributes(password: password));

      // 2. Copy the new password into the managers table.
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

      // 3. Sign out so the manager logs in again with the new password.
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

  InputDecoration _decoration(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: 340,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(18),
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
                const Icon(Icons.lock_reset, size: 44, color: _labelBrown),
                const SizedBox(height: 12),
                const Text(
                  'Set New Password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _darkBrown,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose a strong password for your manager account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPasswords,
                  style: const TextStyle(fontSize: 14),
                  decoration: _decoration(
                    'New password',
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
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmController,
                  obscureText: !_showPasswords,
                  style: const TextStyle(fontSize: 14),
                  onFieldSubmitted: (_) {
                    if (!_isLoading) _handleSave();
                  },
                  decoration: _decoration('Confirm new password'),
                ),
                const SizedBox(height: 6),
                const Text(
                  '8+ characters, uppercase, lowercase, number and special character.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 46,
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(_darkBrown),
                            ),
                          )
                        : const Text(
                            'Save Password',
                            style: TextStyle(
                              fontSize: 15,
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
    );
  }
}