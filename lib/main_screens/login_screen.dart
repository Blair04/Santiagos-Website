import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/main_screens/responsive_side_menu.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  // Supabase Client
  final SupabaseClient _supabase =
      Supabase.instance.client;

  // LOGIN FUNCTION
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password =
        _passwordController.text.trim();

    // VALIDATION
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
      // CHECK ADMIN TABLE
      final List<dynamic> adminCheck =
          await _supabase
              .from('ADMIN')
              .select()
              .eq('email', email)
              .eq('password', password);

      if (adminCheck.isNotEmpty) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const MainResponsivePage(),
            ),
          );
        }
      } else {
        _showSnackBar(
          'Invalid admin email or password.',
          Colors.redAccent,
        );
      }
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

  // SNACKBAR
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

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F4F1),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Container(
            width: 340,

            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 24,
            ),

            decoration: BoxDecoration(
              color: const Color(0xFFD8C9BC),

              borderRadius:
                  BorderRadius.circular(18),

              // CONTAINER SHADOW
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,

              children: [

                // LOGO
                Center(
                  child: Container(
                    width: 78,
                    height: 78,

                    decoration:
                        const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),

                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/santiago_logo.jpg',

                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // EMAIL LABEL
                const Text(
                  'Email',

                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                    color: Color(0xFF5C4635),
                  ),
                ),

                const SizedBox(height: 6),

                // EMAIL FIELD
                TextFormField(
                  controller: _emailController,

                  keyboardType:
                      TextInputType.emailAddress,

                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),

                  decoration: _inputDecoration(
                    hintText:
                        'example@email.com',
                  ),
                ),

                const SizedBox(height: 18),

                // PASSWORD LABEL
                const Text(
                  'Password',

                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                    color: Color(0xFF5C4635),
                  ),
                ),

                const SizedBox(height: 6),

                // PASSWORD FIELD
                TextFormField(
                  controller:
                      _passwordController,

                  obscureText:
                      !_isPasswordVisible,

                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),

                  onFieldSubmitted: (_) =>
                      _isLoading
                          ? null
                          : _handleLogin(),

                  decoration: _inputDecoration(
                    hintText: 'Password',

                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons
                                .visibility_outlined,

                        size: 20,
                        color:
                            Colors.grey.shade600,
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

                const SizedBox(height: 24),

                // LOGIN BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 46,

                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : _handleLogin,

                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                              0xFFE4CFB3),

                      foregroundColor:
                          const Color(
                              0xFF4B3525),

                      elevation: 0,

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                                10),
                      ),
                    ),

                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,

                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,

                              valueColor:
                                  AlwaysStoppedAnimation<
                                      Color>(
                                Color(0xFF4B3525),
                              ),
                            ),
                          )
                        : const Text(
                            'Log in',

                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.w600,
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

  // input design
  InputDecoration _inputDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,

      hintStyle: TextStyle(
        color: Colors.grey.shade500,
        fontSize: 13,
      ),

      filled: true,
      fillColor: Colors.white,

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),

      suffixIcon: suffixIcon,

      enabledBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),

        borderSide: BorderSide(
          color: Colors.black.withOpacity(0.25),
          width: 1,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),

        borderSide: const BorderSide(
          color: Colors.black87,
          width: 1.3,
        ),
      ),
    );
  }
}