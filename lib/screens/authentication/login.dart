import 'package:afpflutter/shared/custom_button.dart';
import 'package:afpflutter/shared/custom_text_field.dart';
import 'package:afpflutter/services/authentication.dart';
import 'package:afpflutter/screens/authentication/otp_verification.dart';
import 'package:flutter/material.dart';

/// Design colors: placeholder grey, field grey, primary blue (1:1 with provided UI).
class _LoginColors {
  static const Color logoPlaceholder = Color(0xFFE0E0E0);
  static const Color fieldFill = Color(0xFFF0F0F0);
  static const Color primaryBlue = Color(0xFF3F3FFF);
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthenticationService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      final response = await _authService.login(
        _emailController.text,
        _passwordController.text,
      );
      if (mounted) {
        if (response['requires_otp'] == true) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationPage(
                email: _emailController.text,
              ),
            ),
          );
        } else {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Responsive horizontal padding: 6% of width, min 16, max 48 (phones vs tablets)
    final horizontalPadding = (screenWidth * 0.06).clamp(16.0, 48.0);
    final padding = EdgeInsets.symmetric(horizontal: horizontalPadding);
    // Constrain content width on tablets for readability
    final maxContentWidth = (screenWidth * 0.85).clamp(320.0, 440.0);
    // Logo placeholder: scale with screen height, keep aspect
    final logoSize = (screenHeight * 0.22).clamp(120.0, 200.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenHeight - MediaQuery.paddingOf(context).vertical,
            ),
            child: Center(
              child: Padding(
                padding: padding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: screenHeight * 0.06),
                      // Logo placeholder: large grey box
                      Center(
                        child: Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            color: _LoginColors.logoPlaceholder,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.05),
                      CustomTextField(
                        label: 'Email',
                        controller: _emailController,
                        hintText: 'Email',
                        fillColor: _LoginColors.fieldFill,
                        suffixIcon: null,
                      ),
                      SizedBox(height: 16),
                      CustomTextField(
                        label: 'Password',
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        hintText: 'Password',
                        fillColor: _LoginColors.fieldFill,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey.shade700,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      CustomButton(
                        label: 'Login',
                        onPressed: _isLoading ? null : _handleLogin,
                        backgroundColor: _LoginColors.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      SizedBox(height: screenHeight * 0.06),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
