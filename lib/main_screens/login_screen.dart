import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _background = Color(0xFFD8C9BC);
  static const Color _cream = Color(0xFFF7F4F1);
  static const Color _darkBrown = Color(0xFF4B3525);
  static const Color _labelBrown = Color(0xFF5C4635);
  static const Color _accent = Color(0xFFE4CFB3);

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final prefs = await SharedPreferences.getInstance();

    final bool isAdminLoggedIn = prefs.getBool('isAdminLoggedIn') ?? false;

    final session = _supabase.auth.currentSession;

    if (isAdminLoggedIn && session != null && mounted) {
      context.go('/home/dashboard');
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar(
        'Please fill in all fields',
        Colors.orangeAccent,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setBool('isAdminLoggedIn', true);

        if (mounted) {
          context.go('/home/dashboard');
        }
      } else {
        _showSnackBar(
          'Invalid email or password.',
          Colors.redAccent,
        );
      }
    } on AuthException catch (error) {
      _showSnackBar(error.message, Colors.redAccent);
    } catch (error) {
      _showSnackBar(
        'An unexpected error occurred. Please check your connection.',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(
    String message,
    Color backgroundColor,
  ) {
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop =
              constraints.maxWidth >= 900 && constraints.maxHeight >= 450;

          if (isDesktop) {
            return _buildDesktopLayout(constraints);
          }

          return _buildMobileLayout(constraints);
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BoxConstraints constraints) {
    final width = constraints.maxWidth;

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: _background,
          ),
        ),

        Positioned.fill(
          child: PhysicalShape(
            clipper: _LoginCircleClipper(),
            color: _cream,
            elevation: 2,
            shadowColor: _darkBrown.withOpacity(0.10),
            child: const SizedBox.expand(),
          ),
        ),

        Positioned(
          left: width * 0.075,
          width: width * 0.43,
          top: 0,
          bottom: 0,
          child: Center(
            child: _buildLogo(),
          ),
        ),

        Positioned(
          left: width * 0.575,
          right: width * 0.065,
          top: 0,
          bottom: 0,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                vertical: 35,
                horizontal: 8,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 380,
                ),
                child: _buildLoginForm(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BoxConstraints constraints) {
    final double width = constraints.maxWidth;
    final double height = constraints.maxHeight;

    final bool isShort = height < 560;
    final bool isTablet = width >= 600;

    final double logoSize = isShort
        ? 130
        : math.min(math.max(width * 0.55, 160.0), isTablet ? 280.0 : 240.0);
    final double horizontalPadding = isTablet ? 40 : 28;

    return Container(
      color: _background,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, safeConstraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: safeConstraints.maxHeight,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: isShort ? 16 : 25),
                      Container(
                        width: logoSize,
                        height: logoSize,
                        decoration: const BoxDecoration(
                          color: _cream,
                          shape: BoxShape.circle,
                        ),
                        padding: EdgeInsets.all(logoSize * 0.127),
                        child: Center(
                          child: _buildLogo(),
                        ),
                      ),

                      SizedBox(height: isShort ? 12 : 25),

                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 20,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: _buildLoginForm(),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 560,
      ),
      child: Image.asset(
        'assets/images/santiago_logo_fitted.png',
        width: 450,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Text(
            "SANTIAGO'S FURNITURE",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _darkBrown,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Welcome Back!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: _darkBrown,
          ),
        ),

        const SizedBox(height: 30),

        const Text(
          'Email',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _darkBrown,
          ),
        ),

        const SizedBox(height: 7),

        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
          decoration: _inputDecoration(
            hintText: 'example@gmail.com',
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: _labelBrown,
              size: 20,
            ),
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'Password',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _darkBrown,
          ),
        ),

        const SizedBox(height: 7),

        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
          onFieldSubmitted: (_) {
            if (!_isLoading) {
              _handleLogin();
            }
          },
          decoration: _inputDecoration(
            hintText: 'Password',
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: _labelBrown,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible
                    ? Icons.visibility
                    : Icons.visibility_outlined,
                size: 20,
                color: _labelBrown,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
          ),
        ),

        const SizedBox(height: 5),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push('/forgot-password'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(50, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Forgot Password?',
              style: TextStyle(
                fontSize: 12,
                color: _labelBrown,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: _darkBrown,
              disabledBackgroundColor: _accent.withOpacity(0.7),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _darkBrown,
                      ),
                    ),
                  )
                : const Text(
                    'Log in',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: Colors.grey.shade500,
        fontSize: 13,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: _darkBrown.withOpacity(0.20),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: _darkBrown,
          width: 1.4,
        ),
      ),
    );
  }
}

class _LoginCircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    path.moveTo(0, 0);
    path.lineTo(size.width * 0.15, 0);

    path.cubicTo(
      size.width * 0.63,
      size.height * 0.015,
      size.width * 0.66,
      size.height * 0.84,
      size.width * 0.58,
      size.height,
    );

    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}