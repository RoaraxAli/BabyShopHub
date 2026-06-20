import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'dart:async';
import 'firebase_options.dart';
import 'theme/theme_provider.dart';
import 'services/auth_provider.dart';
import 'services/shop_provider.dart';
import 'screens/splash_screen.dart';
import 'utils/window_helper.dart';

void main() async {
  // Ensure Flutter engine bindings are initialized prior to loading preferences
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ShopProvider()),
      ],
      child: const BabyShopHubApp(),
    ),
  );
}

class BabyShopHubApp extends StatelessWidget {
  const BabyShopHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to theme state updates dynamically
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentUri = Uri.base.toString();

    Widget homeWidget = const SplashScreen();
    if (currentUri.contains('success')) {
      homeWidget = const PaymentSuccessScreen();
    } else if (currentUri.contains('cancel')) {
      homeWidget = const PaymentCancelScreen();
    }

    return MaterialApp(
      title: 'BabyShopHub',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      home: homeWidget,
    );
  }
}

class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({super.key});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _processPaymentSuccess();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _processPaymentSuccess() async {
    String uriStr = getBrowserUrl();
    if (uriStr.isEmpty) {
      uriStr = Uri.base.toString();
    }
    String? orderId;
    final regExp = RegExp(r'[?&]orderId=([^&#]+)');
    final match = regExp.firstMatch(uriStr);
    if (match != null) {
      orderId = match.group(1);
    }

    if (orderId != null && orderId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
          'status': 'Pending',
          'statusHistory': FieldValue.arrayUnion([
            {
              'status': 'Pending',
              'timestamp': Timestamp.now(),
              'note': 'Payment verified via redirect success',
            }
          ]),
        });
      } catch (e) {
        debugPrint('Error updating order status on success: $e');
      }
    }
    
    // Clear cart locally
    if (mounted) {
      Provider.of<ShopProvider>(context, listen: false).clearCart();
    }

    // Automatically close the web tab
    closeWebWindow();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 90),
              SizedBox(height: 24),
              Text(
                'Payment Done Successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'Outfit',
                ),
              ),
              SizedBox(height: 12),
              Text(
                'You can close this page now.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PaymentCancelScreen extends StatefulWidget {
  const PaymentCancelScreen({super.key});

  @override
  State<PaymentCancelScreen> createState() => _PaymentCancelScreenState();
}

class _PaymentCancelScreenState extends State<PaymentCancelScreen> {
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _processPaymentCancel();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _processPaymentCancel() async {
    String uriStr = getBrowserUrl();
    if (uriStr.isEmpty) {
      uriStr = Uri.base.toString();
    }
    String? orderId;
    final regExp = RegExp(r'[?&]orderId=([^&#]+)');
    final match = regExp.firstMatch(uriStr);
    if (match != null) {
      orderId = match.group(1);
    }

    if (orderId != null && orderId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
          'status': 'Cancelled',
          'statusHistory': FieldValue.arrayUnion([
            {
              'status': 'Cancelled',
              'timestamp': Timestamp.now(),
              'note': 'Payment cancelled by user',
            }
          ]),
        });
      } catch (e) {
        debugPrint('Error updating order status on cancel: $e');
      }
    }

    // Automatically close the web tab
    closeWebWindow();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 90),
              SizedBox(height: 24),
              Text(
                'Payment Cancelled',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'Outfit',
                ),
              ),
              SizedBox(height: 12),
              Text(
                'You can close this page now.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
