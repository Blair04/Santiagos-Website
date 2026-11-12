
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/main_screens/responsive_side_menu.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Original Santiago's Furniture theme
  static const Color _background = Color(0xFFD8C9BC);
  static const Color _cream = Color(0xFFF7F4F1);
  static const Color _darkBrown = Color(0xFF4B3525);
  static const Color _labelBrown = Color(0xFF5C4635);
  static const Color _accent = Color(0xFFE4CFB3);

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  // Check if the manager is already logged in.
  Future<void> _checkSavedSession() async {
    final prefs = await SharedPreferences.getInstance();

    final bool isAdminLoggedIn =
        prefs.getBool('isAdminLoggedIn') ?? false;

    final session = _supabase.auth.currentSession;

    if (isAdminLoggedIn && session != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MainResponsivePage(),
        ),
      );
    }
  }

  // Supabase login functionality.
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
      final response =
          await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setBool('isAdminLoggedIn', true);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const MainResponsivePage(),
            ),
          );
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
              constraints.maxWidth >= 780 &&
              constraints.maxHeight >= 450;

          if (isDesktop) {
            return _buildDesktopLayout(constraints);
          }

          return _buildMobileLayout();
        },
      ),
    );
  }

  // DESKTOP LOGIN LAYOUT
  // Large curved circular area on the left, login form on right.

  Widget _buildDesktopLayout(BoxConstraints constraints) {
    final width = constraints.maxWidth;

    return Stack(
      children: [
        // Entire background uses the original light brown theme.
        Positioned.fill(
          child: Container(
            color: _background,
          ),
        ),

        // Large cream circular/curved area on the left.
        Positioned.fill(
          child: ClipPath(
            clipper: _LoginCircleClipper(),
            child: Container(
              color: _cream,
            ),
          ),
        ),

        // Santiago's Furniture logo centered in the left area.
        
Positioned(
  left: width * 0.075,
  width: width * 0.48,
  top: 0,
  bottom: 0,
  child: Center(
    child: _buildLogo(),
  ),
),

        // Login form on the right side.
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

  Widget _buildMobileLayout() {
    return Container(
      color: _background,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 25),

              // Circular logo area.
              Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(
                  color: _cream,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: _buildLogo(),
                ),
              ),

              const SizedBox(height: 25),

              // Login form.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 20,
                ),
                child: _buildLoginForm(),
              ),

              const SizedBox(height: 20),
            ],
          ),
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
      width: 560,
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

        // EMAIL
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

        // PASSWORD
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
                  _isPasswordVisible =
                      !_isPasswordVisible;
                });
              },
            ),
          ),
        ),

        const SizedBox(height: 5),

        // FORGOT PASSWORD
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const ForgotPasswordScreen(),
                ),
              );
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(50, 30),
              tapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,
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

        // LOGIN BUTTON
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: _darkBrown,
              disabledBackgroundColor:
                  _accent.withOpacity(0.7),
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
                      valueColor:
                          AlwaysStoppedAnimation<Color>(
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

        const SizedBox(height: 18),

        // CREATE ACCOUNT
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              "Don't have an account? ",
              style: TextStyle(
                fontSize: 12,
                color: _labelBrown,
              ),
            ),

            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const RegisterScreen(),
                  ),
                );
              },
              child: const Text(
                'Create account',
                style: TextStyle(
                  fontSize: 12,
                  color: _darkBrown,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
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

    // Start of the curved circle at the top.
    path.lineTo(size.width * 0.16, 0);

    // Large rounded curve on the right side.
    path.cubicTo(
      size.width * 0.92,
      size.height * 0.05,
      size.width * 0.92,
      size.height * 0.95,
      size.width * 0.16,
      size.height,
    );

    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(
    covariant CustomClipper<Path> oldClipper,
  ) {
    return false;
  }
}
