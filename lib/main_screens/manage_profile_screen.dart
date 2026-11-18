import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'email_change_otp_screen.dart';

/// Lets the signed-in manager update the business logo and login credentials
/// through Supabase Auth. Email changes are mirrored into `managers` only
/// after Supabase confirms both email-change OTPs.
class ManageProfileScreen extends StatefulWidget {
  final VoidCallback? onProfileUpdated;

  const ManageProfileScreen({super.key, this.onProfileUpdated});

  @override
  State<ManageProfileScreen> createState() => _ManageProfileScreenState();
}

class _ManageProfileScreenState extends State<ManageProfileScreen> {
  static const Color _background = Color(0xFFF9F6F0);
  static const Color _ink = Color(0xFF2C2221);
  static const Color _bronze = Color(0xFFC68B59);
  static const Color _darkBrown = Color(0xFF6D4C41);
  static const Color _sage = Color(0xFF438A5E);
  static const Color _mutedRed = Color(0xFFD9534F);
  static const String _localAvatarKey = 'santiagoBusinessLogoBase64';

  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  Uint8List? _avatarBytes;
  String? _remoteAvatarUrl;
  bool _isUploadingAvatar = false;
  bool _isUpdatingEmail = false;
  bool _isUpdatingPassword = false;
  bool _showPasswords = false;

  User? get _currentUser => _supabase.auth.currentUser;

  // A strong password must satisfy every rule below.
  bool get _hasMinPasswordLength => _passwordController.text.length >= 8;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_passwordController.text);
  bool get _hasLowercase => RegExp(r'[a-z]').hasMatch(_passwordController.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_passwordController.text);
  bool get _hasSpecialCharacter =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/~;]')
          .hasMatch(_passwordController.text);

  int get _passwordStrengthScore => [
        _hasMinPasswordLength,
        _hasUppercase,
        _hasLowercase,
        _hasNumber,
        _hasSpecialCharacter,
      ].where((passed) => passed).length;

  bool get _isStrongPassword => _passwordStrengthScore == 5;

  bool get _passwordsMatch =>
      _confirmPasswordController.text.isNotEmpty &&
      _passwordController.text == _confirmPasswordController.text;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_refreshPasswordFeedback);
    _confirmPasswordController.addListener(_refreshPasswordFeedback);
    _remoteAvatarUrl =
        _currentUser?.userMetadata?['business_logo_url']?.toString().trim();
    _loadLocalAvatar();
  }

  void _refreshPasswordFeedback() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLocalAvatar() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_localAvatarKey);
    if (encoded == null || encoded.isEmpty || !mounted) return;
    try {
      setState(() => _avatarBytes = base64Decode(encoded));
    } catch (_) {
      await preferences.remove(_localAvatarKey);
    }
  }

  /// Saves the selected photo locally first, then attempts to synchronize it
  /// with an existing `avatars` bucket.
  Future<void> _pickAndUploadAvatar() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      _showMessage('Choose a business logo image smaller than 5 MB.', _mutedRed);
      return;
    }

    setState(() {
      _avatarBytes = bytes;
      _isUploadingAvatar = true;
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_localAvatarKey, base64Encode(bytes));
    widget.onProfileUpdated?.call();

    var synchronized = false;
    final user = _currentUser;
    if (user != null) {
      final extension = image.name.toLowerCase().endsWith('.png')
          ? 'png'
          : image.name.toLowerCase().endsWith('.webp')
          ? 'webp'
          : 'jpg';
      final contentType = extension == 'png'
          ? 'image/png'
          : extension == 'webp'
          ? 'image/webp'
          : 'image/jpeg';
      final path = '${user.id}/business-logo.$extension';

      try {
        await _supabase.storage
            .from('avatars')
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(upsert: true, contentType: contentType),
            );
        final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);
        await _supabase.auth.updateUser(
          UserAttributes(data: {'business_logo_url': publicUrl}),
        );
        _remoteAvatarUrl = publicUrl;
        synchronized = true;
      } catch (_) {
        // No avatars bucket / policy: the local copy remains available.
      }
    }

    if (!mounted) return;
    setState(() => _isUploadingAvatar = false);
    _showMessage(
      synchronized
          ? 'Business logo updated successfully.'
          : 'Business logo saved on this browser. Cloud sync was unavailable.',
      _sage,
    );
  }

  Future<void> _updateEmail() async {
    final user = _currentUser;
    if (user == null || user.email == null) {
      _showMessage('Your session has expired. Please log in again.', _mutedRed);
      return;
    }

    final newEmailController = TextEditingController();
    final currentPasswordController = TextEditingController();
    var obscurePassword = true;

    final request = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Change Email Address', style: TextStyle(color: _ink, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current email: ${user.email}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                const SizedBox(height: 18),
                const Text('New email address', style: TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 7),
                TextField(
                  controller: newEmailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: _inputDecoration(hintText: 'Enter your new email', icon: Icons.mail_outline_rounded),
                ),
                const SizedBox(height: 16),
                const Text('Current password', style: TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 7),
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscurePassword,
                  decoration: _inputDecoration(hintText: 'Confirm your current password', icon: Icons.lock_outline_rounded).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                      icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text('We will send verification codes to your current and new email addresses.', style: TextStyle(color: Colors.grey.shade700, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _darkBrown, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(dialogContext, {
                  'email': newEmailController.text.trim(),
                  'password': currentPasswordController.text,
                });
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );

    newEmailController.dispose();
    currentPasswordController.dispose();
    if (request == null) return;

    final newEmail = request['email'] ?? '';
    final currentPassword = request['password'] ?? '';
    if (!_isValidEmail(newEmail)) {
      _showMessage('Enter a valid email address.', _mutedRed);
      return;
    }
    if (newEmail.toLowerCase() == user.email!.toLowerCase()) {
      _showMessage('This is already your current email.', _bronze);
      return;
    }
    if (currentPassword.isEmpty) {
      _showMessage('Enter your current password to continue.', _mutedRed);
      return;
    }

    setState(() => _isUpdatingEmail = true);
    try {
      // Re-authenticate with the current credentials before starting a sensitive change.
      final authResponse = await _supabase.auth.signInWithPassword(
        email: user.email!,
        password: currentPassword,
      );
      if (authResponse.user == null || authResponse.user!.id != user.id) {
        throw Exception('Unable to verify your account. Please sign in again.');
      }

      // Supabase enforces email uniqueness and sends both OTPs because
      // Secure email change is enabled in the project's Email provider.
      await _supabase.auth.updateUser(UserAttributes(email: newEmail));

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmailChangeOtpScreen(
            oldEmail: user.email!,
            newEmail: newEmail,
            userId: user.id,
          ),
        ),
      );
      widget.onProfileUpdated?.call();
    } on AuthException catch (error) {
      if (mounted) _showMessage(error.message, _mutedRed);
    } catch (error) {
      if (mounted) _showMessage('Could not start the email change. Please try again.', _mutedRed);
    } finally {
      if (mounted) setState(() => _isUpdatingEmail = false);
    }
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    final confirmation = _confirmPasswordController.text;
    final user = _currentUser;

    if (!_isStrongPassword) {
      _showMessage(
        'Create a strong password by meeting all five security requirements.',
        _mutedRed,
      );
      return;
    }
    if (password != confirmation) {
      _showMessage('The password confirmation does not match.', _mutedRed);
      return;
    }
    if (user == null) {
      _showMessage('Auth session missing. Please log in again.', _mutedRed);
      return;
    }

    setState(() => _isUpdatingPassword = true);
    try {
      // The login password lives in Supabase Auth.
      await _supabase.auth.updateUser(UserAttributes(password: password));

      // Passwords must remain exclusively in Supabase Auth; never store them
      // as readable values in the managers table.

      _passwordController.clear();
      _confirmPasswordController.clear();
      if (!mounted) return;
      _showMessage('Password updated successfully.', _sage);
    } on AuthException catch (error) {
      _showMessage(error.message, _mutedRed);
    } catch (_) {
      _showMessage('The password could not be updated.', _mutedRed);
    } finally {
      if (mounted) setState(() => _isUpdatingPassword = false);
    }
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 600
              ? 18.0
              : constraints.maxWidth < 1000
              ? 24.0
              : 40.0;
          final useColumns = constraints.maxWidth >= 940;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              constraints.maxWidth < 600 ? 24 : 40,
              horizontalPadding,
              48,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage Account',
                      style: TextStyle(
                        color: Colors.brown,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manage your business logo and manager sign-in details.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 15),

                    const Divider(
                      color: Color(0xFFE0DAD5),
                      thickness: 1,
                      height: 1,
                    ),
                    const SizedBox(height: 25),

                    if (useColumns)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: _buildProfileCard()),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 6,
                            child: Column(
                              children: [
                                _buildEmailCard(),
                                const SizedBox(height: 24),
                                _buildPasswordCard(),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildProfileCard(),
                      const SizedBox(height: 20),
                      _buildEmailCard(),
                      const SizedBox(height: 20),
                      _buildPasswordCard(),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileCard() {
    return _buildSectionCard(
      title: 'Business Logo',
      subtitle: 'Company logo • JPG, PNG, or WebP up to 5 MB',
      child: Column(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _darkBrown.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: _ink.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(child: _buildAvatarImage()),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "Santiago's Furniture",
            style: TextStyle(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Official business logo',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isUploadingAvatar ? null : _pickAndUploadAvatar,
              icon: const Icon(Icons.upload_outlined),
              label: const Text('Change Business Logo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _darkBrown,
                side: BorderSide(color: _darkBrown.withValues(alpha: 0.45)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage() {
    if (_avatarBytes != null) {
      return Image.memory(_avatarBytes!, fit: BoxFit.cover);
    }
    if (_remoteAvatarUrl != null && _remoteAvatarUrl!.isNotEmpty) {
      return Image.network(
        _remoteAvatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallbackAvatar(),
      );
    }
    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    return Image.asset('assets/images/santiago_logo.jpg', fit: BoxFit.cover);
  }

  Widget _buildEmailCard() {
    final currentEmail = _currentUser?.email ?? 'No email available';
    return _buildSectionCard(
      title: 'Email Address',
      subtitle: 'Update the address used to sign in as manager.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Current email', style: TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFE0DAD5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.mail_outline_rounded, size: 18, color: _darkBrown),
                const SizedBox(width: 10),
                Expanded(child: Text(currentEmail, style: const TextStyle(color: _ink, fontSize: 14))),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isUpdatingEmail ? null : _updateEmail,
              style: _primaryButtonStyle(),
              icon: _isUpdatingEmail ? _buttonProgress() : const Icon(Icons.edit_outlined, size: 18),
              label: Text(_isUpdatingEmail ? 'Please wait...' : 'Change email'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordCard() {
    return _buildSectionCard(
      title: 'Password & Security',
      subtitle: 'Create a strong password to protect the manager account.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New password',
            style: TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: !_showPasswords,
            autofillHints: const [AutofillHints.newPassword],
            decoration: _passwordDecoration('Enter a new password'),
          ),
          const SizedBox(height: 14),
          _buildPasswordStrengthIndicator(),
          const SizedBox(height: 14),
          _buildPasswordRequirements(),
          const SizedBox(height: 20),
          const Text(
            'Confirm password',
            style: TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmPasswordController,
            obscureText: !_showPasswords,
            onSubmitted: (_) =>
                _isUpdatingPassword ? null : _updatePassword(),
            decoration: _passwordDecoration('Repeat the new password'),
          ),
          if (_confirmPasswordController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _passwordsMatch ? Icons.check_circle : Icons.error_outline,
                  size: 15,
                  color: _passwordsMatch ? _sage : _mutedRed,
                ),
                const SizedBox(width: 6),
                Text(
                  _passwordsMatch
                      ? 'Passwords match'
                      : 'Passwords do not match',
                  style: TextStyle(
                    color: _passwordsMatch ? _sage : _mutedRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isUpdatingPassword ||
                      !_isStrongPassword ||
                      !_passwordsMatch
                  ? null
                  : _updatePassword,
              style: _primaryButtonStyle(),
              icon: _isUpdatingPassword
                  ? _buttonProgress()
                  : const Icon(Icons.lock_reset_rounded, size: 18),
              label: const Text('Update password'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    final score = _passwordStrengthScore;
    final hasInput = _passwordController.text.isNotEmpty;

    final Color strengthColor;
    final String strengthLabel;

    if (!hasInput) {
      strengthColor = Colors.grey.shade400;
      strengthLabel = 'Not entered';
    } else if (score <= 2) {
      strengthColor = _mutedRed;
      strengthLabel = 'Weak';
    } else if (score <= 4) {
      strengthColor = _bronze;
      strengthLabel = 'Moderate';
    } else {
      strengthColor = _sage;
      strengthLabel = 'Strong';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Password strength',
              style: TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              strengthLabel,
              style: TextStyle(
                color: strengthColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: List.generate(5, (index) {
              final active = hasInput && index < score;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: index == 4 ? 0 : 5),
                  color: active ? strengthColor : const Color(0xFFEAE5E0),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirements() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ink.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password requirements: ',
            style: TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _buildRequirementRow('At least 8 characters', _hasMinPasswordLength),
          _buildRequirementRow('One uppercase letter (A–Z)', _hasUppercase),
          _buildRequirementRow('One lowercase letter (a–z)', _hasLowercase),
          _buildRequirementRow('At least one number (0–9)', _hasNumber),
          _buildRequirementRow(
            'At least one special character (!@#\$...)',
            _hasSpecialCharacter,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String label, bool passed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 15,
            color: passed ? _sage : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: passed ? _sage : Colors.grey.shade600,
              fontSize: 11,
              fontWeight: passed ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _ink.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.025),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon, color: _darkBrown, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFFCFAF8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _ink.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _ink.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _darkBrown, width: 1.5),
      ),
    );
  }

  InputDecoration _passwordDecoration(String hintText) {
    return _inputDecoration(
      hintText: hintText,
      icon: Icons.lock_outline_rounded,
      suffixIcon: IconButton(
        tooltip: _showPasswords ? 'Hide passwords' : 'Show passwords',
        onPressed: () => setState(() => _showPasswords = !_showPasswords),
        icon: Icon(
          _showPasswords
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
        ),
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: _darkBrown,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    );
  }

  Widget _buttonProgress() {
    return const SizedBox(
      width: 17,
      height: 17,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}