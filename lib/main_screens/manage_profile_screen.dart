import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lets the signed-in administrator update account details without changing
/// the application's existing Supabase project or database structure.
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
  static const Color _sage = Color(0xFF438A5E);
  static const Color _mutedRed = Color(0xFFD9534F);
  static const String _localAvatarKey = 'adminProfileAvatarBase64';

  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _emailController = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    _emailController.text = _currentUser?.email ?? '';
    _remoteAvatarUrl = _currentUser?.userMetadata?['avatar_url']
        ?.toString()
        .trim();
    _loadLocalAvatar();
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
  /// with an existing `avatars` bucket. Local persistence keeps the feature
  /// usable without adding a bucket, policy, or other Supabase structure.
  Future<void> _pickAndUploadAvatar() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 82,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      _showMessage('Choose an image smaller than 5 MB.', _mutedRed);
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
      final path = '${user.id}/avatar.$extension';

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
          UserAttributes(data: {'avatar_url': publicUrl}),
        );
        _remoteAvatarUrl = publicUrl;
        synchronized = true;
      } catch (_) {
        // The existing project may not have an avatars bucket. The local copy
        // remains available and no backend structure is created automatically.
      }
    }

    if (!mounted) return;
    setState(() => _isUploadingAvatar = false);
    _showMessage(
      synchronized
          ? 'Profile photo updated successfully.'
          : 'Profile photo saved on this browser.',
      _sage,
    );
  }

  Future<void> _updateEmail() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      _showMessage('Enter a valid email address.', _mutedRed);
      return;
    }
    if (email == _currentUser?.email) {
      _showMessage('This is already your current email.', _bronze);
      return;
    }

    setState(() => _isUpdatingEmail = true);
    try {
      await _supabase.auth.updateUser(UserAttributes(email: email));
      if (!mounted) return;
      _showMessage(
        'Email update submitted. Check for a confirmation message if required.',
        _sage,
      );
      widget.onProfileUpdated?.call();
    } on AuthException catch (error) {
      _showMessage(error.message, _mutedRed);
    } catch (_) {
      _showMessage('The email could not be updated.', _mutedRed);
    } finally {
      if (mounted) setState(() => _isUpdatingEmail = false);
    }
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    final confirmation = _confirmPasswordController.text;
    if (password.length < 8) {
      _showMessage('Use at least 8 characters for the password.', _mutedRed);
      return;
    }
    if (password != confirmation) {
      _showMessage('The password confirmation does not match.', _mutedRed);
      return;
    }

    setState(() => _isUpdatingPassword = true);
    try {
      await _supabase.auth.updateUser(UserAttributes(password: password));
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
                      'Manage Profile',
                      style: TextStyle(
                        color: _ink,
                        fontSize: constraints.maxWidth < 600 ? 28 : 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Keep the administrator photo, email, and password up to date.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 28),
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
      title: 'Profile Photo',
      subtitle: 'JPG, PNG, or WebP up to 5 MB',
      child: Column(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _bronze.withValues(alpha: 0.35),
                      ),
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
                Positioned(
                  right: 2,
                  bottom: 4,
                  child: IconButton.filled(
                    tooltip: 'Choose profile photo',
                    onPressed: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                    style: IconButton.styleFrom(
                      backgroundColor: _bronze,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isUploadingAvatar
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt_outlined, size: 19),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Administrator',
            style: TextStyle(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _currentUser?.email ?? 'No authenticated account',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            _memberSinceLabel(_currentUser),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isUploadingAvatar ? null : _pickAndUploadAvatar,
              icon: const Icon(Icons.upload_outlined),
              label: const Text('Upload photo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _bronze,
                side: BorderSide(color: _bronze.withValues(alpha: 0.45)),
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
    return _buildSectionCard(
      title: 'Email Address',
      subtitle: 'Update the address used to sign in as administrator.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Email',
            style: TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: _inputDecoration(
              hintText: 'administrator@example.com',
              icon: Icons.mail_outline_rounded,
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isUpdatingEmail ? null : _updateEmail,
              style: _primaryButtonStyle(),
              icon: _isUpdatingEmail
                  ? _buttonProgress()
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Update email'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordCard() {
    return _buildSectionCard(
      title: 'Password & Security',
      subtitle: 'Use at least 8 characters and enter the same password twice.',
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
          const SizedBox(height: 16),
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
            onSubmitted: (_) => _isUpdatingPassword ? null : _updatePassword(),
            decoration: _passwordDecoration('Repeat the new password'),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isUpdatingPassword ? null : _updatePassword,
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
      prefixIcon: Icon(icon, color: _bronze, size: 20),
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
        borderSide: const BorderSide(color: _bronze, width: 1.5),
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
      backgroundColor: _bronze,
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

  String _memberSinceLabel(User? user) {
    final created = DateTime.tryParse(user?.createdAt ?? '')?.toLocal();
    if (created == null) return 'Authenticated administrator';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'Member since ${months[created.month - 1]} ${created.year}';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
