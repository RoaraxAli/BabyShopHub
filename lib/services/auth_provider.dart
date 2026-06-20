import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:otp/otp.dart';
import '../models/user.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class AuthProvider extends ChangeNotifier {
  UserProfile? _currentUser;
  bool _isLoading = false;
  String? _otpCode; // Email registration/recovery OTP
  String? _pendingEmail; // Email awaiting validation
  String? _pendingPassword; // Password awaiting TOTP validation

  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user == null) {
        _currentUser = null;
        _isInitialized = true;
        notifyListeners();
        // Clear prefs
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_uid');
          await prefs.remove('auth_email');
          await prefs.remove('auth_display_name');
          await prefs.remove('auth_avatar');
          await prefs.remove('auth_role');
          await prefs.remove('auth_totp_enabled');
          await prefs.remove('auth_totp_secret');
        } catch (e) {
          debugPrint('[AUTH PROVIDER ERROR] Failed to clear SharedPreferences: $e');
        }
      } else {
        try {
          // Fetch user doc from Firestore
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final data = doc.data();
          final role = data?['role'] ?? (user.email?.toLowerCase().contains('admin') == true ? 'admin' : 'user');
          final displayName = data?['displayName'] ?? user.displayName ?? user.email?.split('@')[0] ?? 'Parent';
          final avatarIndex = data?['avatarIndex'] ?? 0;
          final profilePicture = data?['profilePicture'] as String?;
          final isTotpEnabled = data?['isTotpEnabled'] ?? false;
          final totpSecret = data?['totpSecret'];

          _currentUser = UserProfile(
            uid: user.uid,
            email: user.email ?? '',
            displayName: displayName,
            avatarIndex: avatarIndex,
            profilePicture: profilePicture,
            isTotpEnabled: isTotpEnabled,
            totpSecret: totpSecret,
            role: role,
          );

          // Persist session
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_uid', user.uid);
          await prefs.setString('auth_email', user.email ?? '');
          await prefs.setString('auth_display_name', displayName);
          await prefs.setInt('auth_avatar', avatarIndex);
          await prefs.setBool('auth_totp_enabled', isTotpEnabled);
          if (totpSecret != null) {
            await prefs.setString('auth_totp_secret', totpSecret);
          }
          await prefs.setString('auth_role', role);

          _isInitialized = true;
          notifyListeners();
          
          await fetchUserData();
        } catch (e) {
          debugPrint('[AUTH PROVIDER ERROR] Auth listener user load failed: $e');
          // Fallback to minimal user profile if Firestore read fails
          _currentUser = UserProfile(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? user.email?.split('@')[0] ?? 'Parent',
            role: user.email?.toLowerCase().contains('admin') == true ? 'admin' : 'user',
          );
          _isInitialized = true;
          notifyListeners();
        }
      }
    }, onError: (e) {
      debugPrint('[AUTH PROVIDER ERROR] Auth listener failed: $e');
      _isInitialized = true;
      notifyListeners();
    });
  }

  // --- Unified REST API Email Dispatcher (Production Standard) ---
  Future<void> _triggerZohoEmail({
    required String type,
    required String email,
    required Map<String, dynamic> data,
  }) async {
    final String subject;
    final String htmlContent;

    if (type == 'REGISTRATION_OTP') {
      final otp = data['otp'] ?? '';
      subject = 'Verify Your Email - BabyShopHub OTP';
      htmlContent = '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 12px;">
          <h2 style="color: #FF9EAA; text-align: center;">Verify Your Email Address</h2>
          <p>Hello,</p>
          <p>Thank you for registering at BabyShopHub. Please use the following One-Time Password (OTP) to verify your email address and complete registration:</p>
          <div style="background-color: #f7f7f7; padding: 16px; border-radius: 8px; margin: 20px 0; text-align: center; font-size: 24px; font-weight: bold; letter-spacing: 4px; color: #FF9EAA;">
            $otp
          </div>
          <p>This code will expire shortly. If you did not request this, you can ignore this email.</p>
          <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 20px 0;" />
          <p style="font-size: 11px; color: #999; text-align: center;">BabyShopHub Security Operations</p>
        </div>
      ''';
    } else if (type == 'PASSWORD_RESET_OTP') {
      final otp = data['otp'] ?? '';
      subject = 'Reset Your Password - BabyShopHub OTP';
      htmlContent = '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 12px;">
          <h2 style="color: #FF9EAA; text-align: center;">Reset Your Password</h2>
          <p>Hello,</p>
          <p>We received a request to reset your password. Use the following One-Time Password (OTP) to proceed:</p>
          <div style="background-color: #f7f7f7; padding: 16px; border-radius: 8px; margin: 20px 0; text-align: center; font-size: 24px; font-weight: bold; letter-spacing: 4px; color: #FF9EAA;">
            $otp
          </div>
          <p>If you did not request a password reset, please secure your account immediately.</p>
          <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 20px 0;" />
          <p style="font-size: 11px; color: #999; text-align: center;">BabyShopHub Security Operations</p>
        </div>
      ''';
    } else if (type == 'WELCOME') {
      final name = data['name'] ?? 'Parent';
      subject = 'Welcome to BabyShopHub! 👶';
      htmlContent = '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 12px;">
          <h1 style="color: #FF9EAA; text-align: center;">Welcome to BabyShopHub! 👶</h1>
          <p>Dear <strong>$name</strong>,</p>
          <p>Thank you so much for joining our family. We are thrilled to help you on your parenting journey with premium products designed for care, comfort, and joy.</p>
          <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 20px 0;" />
          <p style="font-size: 11px; color: #999; text-align: center;">BabyShopHub Family</p>
        </div>
      ''';
    } else if (type == 'LOGIN_NOTIFICATION') {
      final time = data['time'] ?? '';
      subject = '⚠️ Security Alert: Login Notification';
      htmlContent = '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #FFCDD2; border-radius: 12px;">
          <h2 style="color: #D32F2F; text-align: center;">⚠️ Security Alert: New Login</h2>
          <p>Hello,</p>
          <p>We detected a new login action on your BabyShopHub account.</p>
          <div style="background-color: #FFEBEE; border-left: 4px solid #D32F2F; padding: 12px; border-radius: 4px; margin: 20px 0;">
            <p style="margin: 0; font-size: 13px;"><strong>Time:</strong> $time</p>
          </div>
          <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 20px 0;" />
          <p style="font-size: 11px; color: #999; text-align: center;">BabyShopHub Security Operations</p>
        </div>
      ''';
    } else if (type == 'CHECKOUT_SUCCESS') {
      subject = 'Order Confirmed - BabyShopHub';
      final prefs = await SharedPreferences.getInstance();
      final rawCurrency = prefs.getString('currency_symbol') ?? '\$';
      final currencySymbol = rawCurrency.trim().toUpperCase() == 'PKR' ? 'Rs ' : rawCurrency;

      final total = (data['total'] ?? 0.0) as double;
      final address = data['address'] ?? 'Simulated Delivery Address';
      String itemsRows = '';
      if (data['items'] != null && data['items'] is List) {
        for (var item in data['items']) {
          final name = item['name'] ?? '';
          final qty = item['quantity'] ?? 1;
          final price = (item['price'] ?? 0.0) as double;
          itemsRows += '''
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #eee;">$name (x$qty)</td>
              <td style="padding: 8px; border-bottom: 1px solid #eee; text-align: right;">$currencySymbol${(price * qty).toStringAsFixed(2)}</td>
            </tr>
          ''';
        }
      }
      htmlContent = '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 12px;">
          <h2 style="color: #FF9EAA; text-align: center;">Your Order is Confirmed</h2>
          <p>Thank you for your purchase. We are preparing your baby products with love and care.</p>
          <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
            <thead>
              <tr style="background-color: #f7f7f7;">
                <th style="padding: 8px; text-align: left; border-bottom: 2px solid #ddd;">Product Item</th>
                <th style="padding: 8px; text-align: right; border-bottom: 2px solid #ddd;">Total</th>
              </tr>
            </thead>
            <tbody>
              $itemsRows
            </tbody>
            <tfoot>
              <tr>
                <td style="padding: 8px; font-weight: bold;">Grand Total:</td>
                <td style="padding: 8px; font-weight: bold; text-align: right; color: #FF9EAA;">$currencySymbol${total.toStringAsFixed(2)}</td>
              </tr>
            </tfoot>
          </table>
          <div style="background-color: #f9f9f9; padding: 12px; border-radius: 8px; margin-top: 16px;">
            <p style="margin: 0; font-size: 13px;"><strong>Delivery Shipping Address:</strong><br/>$address</p>
          </div>
          <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 20px 0;" />
          <p style="font-size: 11px; color: #999; text-align: center;">BabyShopHub Logistics Division</p>
        </div>
      ''';
    } else {
      subject = 'Notification from BabyShopHub';
      htmlContent = '<p>Notification from BabyShopHub</p>';
    }

    // Dev print fallback for instant OTP capture during development
    debugPrint('\n========================================================================');
    debugPrint('   [UNIFIED SMTP RELAY] - EMAIL ACTION DISPATCHED');
    debugPrint('   To: $email | Subject: $subject');
    if (data.containsKey('otp')) {
      debugPrint('   👉 OTP CODE IS: ${data['otp']} 👈');
    } else {
      debugPrint('   Payload: $data');
    }
    debugPrint('========================================================================\n');

    // Direct Zoho SMTP Setup
    if (kIsWeb) {
      debugPrint('Skipping real SMTP email send on Web platform (RawSocket unsupported).');
      return;
    }
    final String username = 'no-reply@theali.app';
    final String password = 'YOUR_ZOHO_APP_PASSWORD_HERE'; // Replace with actual app password
    
    if (password == 'YOUR_ZOHO_APP_PASSWORD_HERE') {
      debugPrint('Skipping real SMTP email send because Zoho password is not configured.');
      return;
    }

    final smtpServer = SmtpServer('smtp.zoho.com',
        port: 465,
        ssl: true,
        username: username,
        password: password);

    final message = Message()
      ..from = Address(username, 'BabyShopHub')
      ..recipients.add(email)
      ..subject = subject
      ..html = htmlContent;

    try {
      final sendReport = await send(message, smtpServer);
      debugPrint('Message sent: ' + sendReport.toString());
    } on MailerException catch (e) {
      debugPrint('Message not sent. \n' + e.toString());
      for (var p in e.problems) {
        debugPrint('Problem: ${p.code}: ${p.msg}');
      }
      throw Exception('Failed to send email: ${e.message}');
    }
  }

  // --- Pure-Dart TOTP 2FA Google Authenticator Engine ---
  String generateTotpSecret() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'; // Base32 alphabet
    final rand = Random();
    return List.generate(16, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  bool verifyTotpCode(String secret, String code) {
    if (code.length != 6) return false;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Check current, previous, and next time steps to gracefully handle mobile clock drift!
    for (int i = -1; i <= 1; i++) {
      final timeToVerify = now + (i * 30000);
      try {
        final expectedCode = OTP.generateTOTPCodeString(secret, timeToVerify, algorithm: Algorithm.SHA1, isGoogle: true);
        if (expectedCode == code) {
          return true;
        }
      } catch (e) {
        debugPrint('TOTP Error: $e');
      }
    }
    return false;
  }

  // --- Authenticator Setup Toggles ---
  Future<bool> enableTotp(String secret, String inputCode) async {
    if (verifyTotpCode(secret, inputCode)) {
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          isTotpEnabled: true,
          totpSecret: secret,
        );
        notifyListeners();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('auth_totp_enabled', true);
        await prefs.setString('auth_totp_secret', secret);

        // Record setting state in Firestore users document
        try {
          await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).update({
            'isTotpEnabled': true,
            'totpSecret': secret,
          });
        } catch (e) {
          debugPrint('[AUTH PROVIDER ERROR] Failed to enable TOTP in Firestore: $e');
        }

        return true;
      }
    }
    return false;
  }

  Future<void> disableTotp() async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        isTotpEnabled: false,
        totpSecret: null,
      );
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auth_totp_enabled', false);
      await prefs.remove('auth_totp_secret');

      try {
        await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).update({
          'isTotpEnabled': false,
          'totpSecret': null,
        });
      } catch (e) {
        debugPrint('[AUTH PROVIDER ERROR] Failed to disable TOTP in Firestore: $e');
      }
    }
  }

  // Check if OTP verification is required on signup (synced from Firestore)
  Future<bool> isOtpVerificationRequired() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('admin_settings').doc('store').get();
      if (snap.exists) {
        return snap.data()?['requireEmailVerification'] ?? false;
      }
    } catch (e) {
      debugPrint('[AUTH PROVIDER] Error loading verification settings: $e');
    }
    return false;
  }

  // Register user directly when OTP is disabled by admin
  Future<bool> registerDirectlyWithoutOtp({
    required String email,
    required String password,
    required String name,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final UserCredential creds = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = creds.user;
      if (user == null) throw Exception('Auth creation failed');

      final role = email.toLowerCase().contains('admin') ? 'admin' : 'user';

      _currentUser = UserProfile(
        uid: user.uid,
        email: email,
        displayName: name,
        avatarIndex: 0,
        role: role,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_uid', user.uid);
      await prefs.setString('auth_email', email);
      await prefs.setString('auth_display_name', name);
      await prefs.setInt('auth_avatar', 0);
      await prefs.setBool('auth_totp_enabled', false);
      await prefs.setString('auth_role', role);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'displayName': name,
        'avatarIndex': 0,
        'isTotpEnabled': false,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _triggerZohoEmail(
        type: 'WELCOME',
        email: email,
        data: {'name': name},
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Direct Registration Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- Registration / Verification (Send email OTP first) ---
  Future<void> initiateRegistrationOtp(String email) async {
    _isLoading = true;
    notifyListeners();

    _pendingEmail = email;
    // Generate a secure 5-digit registration OTP
    _otpCode = (10000 + Random().nextInt(90000)).toString();

    // Trigger SMTP verification email
    await _triggerZohoEmail(
      type: 'REGISTRATION_OTP',
      email: email,
      data: {'otp': _otpCode},
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> verifyRegistrationAndCreateUser({
    required String email,
    required String password,
    required String name,
    required String inputCode,
  }) async {
    _isLoading = true;
    notifyListeners();

    if (inputCode == _otpCode && email == _pendingEmail) {
      try {
        // 1. Create real user in Firebase Auth
        final UserCredential creds = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = creds.user;
        if (user == null) throw Exception('Auth creation failed');

        final role = email.toLowerCase().contains('admin') ? 'admin' : 'user';

        // 2. Create UserProfile instance
        _currentUser = UserProfile(
          uid: user.uid,
          email: email,
          displayName: name,
          avatarIndex: 0,
          role: role,
        );

        // 3. Persist session data to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_uid', user.uid);
        await prefs.setString('auth_email', email);
        await prefs.setString('auth_display_name', name);
        await prefs.setInt('auth_avatar', 0);
        await prefs.setBool('auth_totp_enabled', false);
        await prefs.setString('auth_role', role);

        // 4. Write user profile to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'displayName': name,
          'avatarIndex': 0,
          'isTotpEnabled': false,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 5. Trigger Welcome Zoho Email
        await _triggerZohoEmail(
          type: 'WELCOME',
          email: email,
          data: {'name': name},
        );

        _otpCode = null;
        _pendingEmail = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } catch (e) {
        debugPrint('Registration Error: $e');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // --- Real Login with Firebase Auth and TOTP checks ---
  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Authenticate with Firebase Authentication
      final UserCredential creds = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = creds.user;
      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return 'Authentication failed.';
      }

      // 2. Retrieve user profile document from Firestore
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();

      final role = data?['role'] ?? 'user';
      final name = data?['displayName'] ?? email.split('@')[0];
      final avatar = data?['avatarIndex'] ?? 0;
      final totpActive = data?['isTotpEnabled'] ?? false;
      final secret = data?['totpSecret'];

      // 3. Handle Two-Factor Challenge
      if (totpActive && secret != null) {
        // Sign out temporarily until TOTP is verified
        await FirebaseAuth.instance.signOut();

        _pendingEmail = email;
        _pendingPassword = password;
        _otpCode = secret; // Store secret temporarily inside verification buffer
        _isLoading = false;
        notifyListeners();
        return 'TOTP_MFA_REQUIRED';
      }

      // 4. Normal Login (No TOTP)
      _currentUser = UserProfile(
        uid: user.uid,
        email: email,
        displayName: name,
        avatarIndex: avatar,
        isTotpEnabled: false,
        role: role,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_uid', user.uid);
      await prefs.setString('auth_email', email);
      await prefs.setString('auth_display_name', name);
      await prefs.setInt('auth_avatar', avatar);
      await prefs.setBool('auth_totp_enabled', false);
      await prefs.setString('auth_role', role);

      // Trigger Zoho login alert email
      await _triggerZohoEmail(
        type: 'LOGIN_NOTIFICATION',
        email: email,
        data: {'time': DateTime.now().toLocal().toString().split('.')[0]},
      );

      await fetchUserData();
      _isLoading = false;
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Incorrect email or password.';
      }
      return e.message ?? 'An unknown error occurred.';
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  // --- Verify Google Authenticator Code ---
  Future<bool> verifyTotpChallenge(String code) async {
    _isLoading = true;
    notifyListeners();

    if (_pendingEmail != null && _pendingPassword != null && _otpCode != null) {
      if (verifyTotpCode(_otpCode!, code)) {
        try {
          // Re-sign in the user now that TOTP is verified
          final UserCredential creds = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _pendingEmail!,
            password: _pendingPassword!,
          );
          final user = creds.user;
          if (user == null) throw Exception('Auth verification failed');

          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final data = doc.data();

          final role = data?['role'] ?? 'user';
          final name = data?['displayName'] ?? _pendingEmail!.split('@')[0];
          final avatar = data?['avatarIndex'] ?? 0;

          _currentUser = UserProfile(
            uid: user.uid,
            email: _pendingEmail!,
            displayName: name,
            avatarIndex: avatar,
            isTotpEnabled: true,
            totpSecret: _otpCode,
            role: role,
          );

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_uid', user.uid);
          await prefs.setString('auth_email', _pendingEmail!);
          await prefs.setString('auth_display_name', name);
          await prefs.setInt('auth_avatar', avatar);
          await prefs.setBool('auth_totp_enabled', true);
          await prefs.setString('auth_totp_secret', _otpCode!);
          await prefs.setString('auth_role', role);

          _pendingEmail = null;
          _pendingPassword = null;
          _otpCode = null;
          await fetchUserData();
          _isLoading = false;
          return true;
        } catch (e) {
          debugPrint('TOTP verification login error: $e');
        }
      }
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // --- Password Recovery OTP dispatches ---
  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    notifyListeners();

    _pendingEmail = email;
    _otpCode = (10000 + Random().nextInt(90000)).toString();

    await _triggerZohoEmail(
      type: 'PASSWORD_RESET_OTP',
      email: email,
      data: {'otp': _otpCode},
    );

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> verifyRecoveryOtp(String code) async {
    if (code == _otpCode && _pendingEmail != null) {
      _otpCode = null;
      _pendingEmail = null;
      return true;
    }
    return false;
  }

  Future<void> updateAvatar(int index) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(avatarIndex: index);
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('auth_avatar', index);

      try {
        await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).update({
          'avatarIndex': index,
        });
      } catch (e) {
        debugPrint('[AUTH PROVIDER ERROR] Failed to update avatar index in Firestore: $e');
      }
    }
  }

  Future<void> updateProfilePicture(String url) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(profilePicture: url);
      notifyListeners();

      try {
        await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).update({
          'profilePicture': url,
        });
      } catch (e) {
        debugPrint('[AUTH PROVIDER ERROR] Failed to update profile picture in Firestore: $e');
      }
    }
  }

  Future<void> updateDisplayName(String name) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(displayName: name);
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_display_name', name);

      try {
        await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).update({
          'displayName': name,
        });
      } catch (e) {
        debugPrint('[AUTH PROVIDER ERROR] Failed to update display name in Firestore: $e');
      }
    }
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      User? user;

      if (kIsWeb) {
        // Web: Use Firebase's native popup (no need for Web Client ID config)
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCredential =
            await FirebaseAuth.instance.signInWithPopup(googleProvider);
        user = userCredential.user;
      } else {
        // Mobile: Use google_sign_in package
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          _isLoading = false;
          notifyListeners();
          return false;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
        user = userCredential.user;
      }

      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final email = user.email ?? '';
      final name = user.displayName ?? email.split('@')[0];
      final role = email.toLowerCase().contains('admin') ? 'admin' : 'user';

      // Check if user profile exists in Firestore, create if not
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();

      if (!doc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'displayName': name,
          'avatarIndex': 0,
          'isTotpEnabled': false,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final data = doc.data();
      _currentUser = UserProfile(
        uid: user.uid,
        email: email,
        displayName: data?['displayName'] ?? name,
        avatarIndex: data?['avatarIndex'] ?? 0,
        role: data?['role'] ?? role,
      );

      // Persist session locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_uid', user.uid);
      await prefs.setString('auth_email', email);
      await prefs.setString('auth_display_name', _currentUser!.displayName);
      await prefs.setInt('auth_avatar', _currentUser!.avatarIndex);
      await prefs.setString('auth_role', _currentUser!.role);
      await prefs.setBool('auth_totp_enabled', false);

      // Send welcome email for new users
      if (!doc.exists) {
        await _triggerZohoEmail(
          type: 'WELCOME',
          email: email,
          data: {'name': name},
        );
      }

      await fetchUserData();
      _isLoading = false;
      return true;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchUserData() async {
    if (_currentUser == null) return;
    final uid = _currentUser!.uid;

    try {
      final addressesSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .get();
      final addresses = addressesSnap.docs
          .map((d) => UserAddress.fromMap(d.id, d.data()))
          .toList();

      final notificationsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .get();
      final notifications = notificationsSnap.docs
          .map((d) => UserNotification.fromMap(d.id, d.data()))
          .toList();

      _currentUser = _currentUser!.copyWith(
        addresses: addresses,
        notifications: notifications,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user addresses/notifications: $e');
    }
  }

  Future<void> addAddress({
    required String title,
    required String recipientName,
    required String phone,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String postalCode,
    required bool isDefault,
  }) async {
    if (_currentUser == null) return;
    final uid = _currentUser!.uid;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .doc();

    final newAddress = UserAddress(
      id: ref.id,
      title: title,
      recipientName: recipientName,
      phone: phone,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      city: city,
      postalCode: postalCode,
      isDefault: isDefault,
    );

    await ref.set(newAddress.toMap());

    if (isDefault) {
      await _clearOtherDefaults(uid, ref.id);
    }

    await fetchUserData();
  }

  Future<void> updateAddress({
    required String addressId,
    required String title,
    required String recipientName,
    required String phone,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String postalCode,
    required bool isDefault,
  }) async {
    if (_currentUser == null) return;
    final uid = _currentUser!.uid;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .doc(addressId);

    final updated = UserAddress(
      id: addressId,
      title: title,
      recipientName: recipientName,
      phone: phone,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      city: city,
      postalCode: postalCode,
      isDefault: isDefault,
    );

    await ref.set(updated.toMap());

    if (isDefault) {
      await _clearOtherDefaults(uid, addressId);
    }

    await fetchUserData();
  }

  Future<void> deleteAddress(String addressId) async {
    if (_currentUser == null) return;
    final uid = _currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .doc(addressId)
        .delete();

    await fetchUserData();
  }

  Future<void> setDefaultAddress(String addressId) async {
    if (_currentUser == null) return;
    final uid = _currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .doc(addressId)
        .update({'isDefault': true});

    await _clearOtherDefaults(uid, addressId);
    await fetchUserData();
  }

  Future<void> _clearOtherDefaults(String uid, String activeId) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .get();

    for (var doc in snap.docs) {
      if (doc.id != activeId && (doc.data()['isDefault'] ?? false) == true) {
        await doc.reference.update({'isDefault': false});
      }
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    if (_currentUser == null) return;
    final uid = _currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});

    await fetchUserData();
  }

  Future<void> addNotification(String targetUserId, String title, String body, String type) async {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(targetUserId)
        .collection('notifications')
        .doc();

    await ref.set({
      'id': ref.id,
      'title': title,
      'body': body,
      'type': type,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (_currentUser != null && _currentUser!.uid == targetUserId) {
      await fetchUserData();
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    notifyListeners();

    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('[AUTH PROVIDER ERROR] Firebase Auth signOut failed: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_uid');
    await prefs.remove('auth_email');
    await prefs.remove('auth_display_name');
    await prefs.remove('auth_avatar');
    await prefs.remove('auth_role');
    await prefs.remove('auth_totp_enabled');
    await prefs.remove('auth_totp_secret');
  }
}
