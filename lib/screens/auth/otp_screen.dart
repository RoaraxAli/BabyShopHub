import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../home_screen.dart';
import '../admin_panel.dart';
import '../delivery_panel.dart';

class OtpScreen extends StatefulWidget {
  final bool isMfa;
  final bool isRecovery;
  final String email;
  final String? password;
  final String? name;

  const OtpScreen({
    super.key,
    required this.isMfa,
    required this.isRecovery,
    required this.email,
    this.password,
    this.name,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  late final int _codeLength;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _codeLength = widget.isMfa ? 6 : 5;
    _controllers = List.generate(_codeLength, (_) => TextEditingController());
    _focusNodes = List.generate(_codeLength, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _nextField(String value, int index) {
    if (value.length == 1 && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Evaluate full code when filled
    final currentCode = _controllers.map((c) => c.text).join();
    if (currentCode.length == _codeLength) {
      _verifyCode(currentCode);
    }
  }

  Future<void> _verifyCode(String code) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    bool success = false;

    if (widget.isMfa) {
      // Authenticator 2FA check
      success = await auth.verifyTotpChallenge(code);
    } else if (widget.isRecovery) {
      // Password reset OTP check
      success = await auth.verifyRecoveryOtp(code);
    } else {
      // Legacy User registration verification (fallback)
      success = await auth.verifyRegistrationAndCreateUser(
        email: widget.email,
        password: widget.password ?? '',
        name: widget.name ?? '',
        inputCode: code,
      );
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isMfa
              ? 'Verification successful! Logging in.'
              : widget.isRecovery
                  ? 'Verification code confirmed.'
                  : 'Email address verified successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      if (widget.isRecovery) {
        Navigator.of(context).pop(true); // Return true to indicate successful verification
      } else {
        final role = auth.currentUser?.role ?? 'user';
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) {
            if (role == 'admin') return const AdminPanel();
            if (role == 'delivery') return const DeliveryPanel();
            return const HomeScreen();
          }),
          (route) => false,
        );
      }
    } else {
      setState(() {
        _hasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid code entered. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);

    String screenTitle = 'Verification Code';
    String screenSubtitle = 'Enter the 5-digit code sent to your inbox';

    if (widget.isMfa) {
      screenTitle = '2FA Authentication';
      screenSubtitle = 'Enter the 6-digit code from Google Authenticator';
    } else if (widget.isRecovery) {
      screenTitle = 'Password Recovery';
      screenSubtitle = 'Enter the 5-digit code sent to ${widget.email}';
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      widget.isMfa ? Icons.lock_person_outlined : Icons.mark_email_unread_outlined,
                      size: 38,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                screenTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                screenSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 48),
              // Code inputs row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  _codeLength,
                  (index) => SizedBox(
                    width: 46,
                    height: 56,
                    child: TextFormField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      autofillHints: null,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(1),
                      ],
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      onChanged: (val) => _nextField(val, index),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _hasError ? Colors.redAccent : theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _hasError
                                ? Colors.redAccent
                                : theme.colorScheme.onSurface.withOpacity(0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _hasError ? Colors.redAccent : theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              if (auth.isLoading)
                const Center(child: CircularProgressIndicator())
              else
                TextButton.icon(
                  onPressed: () {
                    // Reset field states
                    for (var c in _controllers) {
                      c.clear();
                    }
                    setState(() {
                      _hasError = false;
                    });
                    _focusNodes[0].requestFocus();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(
                    'Clear and Restart',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
