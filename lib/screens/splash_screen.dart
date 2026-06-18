import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_provider.dart';
import '../widgets/animated_loader.dart';
import 'onboarding_screen.dart';
import 'auth/welcome_screen.dart';
import 'home_screen.dart';
import 'admin_panel.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startLaunchRoutine();
  }

  Future<void> _startLaunchRoutine() async {
    // Elegant launch delay for branding impression
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('first_launch_done') ?? false;

    if (!isFirstLaunch) {
      // Direct new users to onboarding
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else {
      // Evaluate session details for returning users
      final auth = Provider.of<AuthProvider>(context, listen: false);
      
      // Wait for Firebase Auth listener to initialize
      while (!auth.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final isAdmin = auth.currentUser?.role == 'admin';
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            if (!auth.isAuthenticated) return const WelcomeScreen();
            return isAdmin ? const AdminPanel() : const HomeScreen();
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Gemini-generated beautiful background image with smooth animated opacity/scale
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 1.05, end: 1.0),
              duration: const Duration(milliseconds: 2000),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/splash_bg.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          
          // Subtle soft color overlay
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.1),
            ),
          ),

          // Main content with elegant entry animation
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1600),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AnimatedLoader(
                    size: 90,
                    message: 'BabyShopHub',
                  ),
                  const SizedBox(height: 16),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeIn,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: child,
                      );
                    },
                    child: Text(
                      'Care. Comfort. Joy.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onBackground.withOpacity(0.6),
                        letterSpacing: 2.0,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
