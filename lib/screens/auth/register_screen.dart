import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text;

    final otpRequired = await auth.isOtpVerificationRequired();

    if (!mounted) return;

    if (otpRequired) {
      await auth.initiateRegistrationOtp(email);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP code sent to your email.'),
          backgroundColor: Colors.blue,
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OtpScreen(
            isMfa: false,
            isRecovery: false,
            email: email,
            password: password,
            name: name,
          ),
        ),
      );
    } else {
      final success = await auth.registerDirectlyWithoutOtp(
        email: email,
        password: password,
        name: name,
      );
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration failed. Please check details or try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Cohesive background blobs
          Positioned(
            top: -size.height * 0.12,
            left: -size.width * 0.12,
            child: Container(
              width: size.width * 0.55,
              height: size.width * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.08,
            right: -size.width * 0.1,
            child: Container(
              width: size.width * 0.45,
              height: size.width * 0.45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withOpacity(0.04),
              ),
            ),
          ),
          // Custom Back Button
          Positioned(
            top: 48,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
                foregroundColor: theme.colorScheme.onSurface,
                shadowColor: Colors.black.withOpacity(0.05),
                elevation: 4,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 450),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withOpacity(0.06),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Modern Logo Badge
                        Center(
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.primary.withOpacity(0.12),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.child_care_rounded,
                                size: 38,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Create Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                            fontFamily: 'Outfit',
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join BabyShopHub for convenient infant shopping',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 32),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Enter your name';
                                  if (val.trim().length < 2) return 'Name must be at least 2 characters';
                                  return null;
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                                ),
                                style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Enter your email address';
                                  final reg = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                  if (!reg.hasMatch(val)) return 'Enter a valid email address';
                                  return null;
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                                ),
                                style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Enter a password';
                                  if (val.length < 6) return 'Password must be at least 6 characters';
                                  return null;
                                },
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: auth.isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Create Account',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already registered? ',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                                fontSize: 13,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Text(
                                'Log in',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
