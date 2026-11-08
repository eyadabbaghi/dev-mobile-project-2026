import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../dashboard/main_dashboard_screen.dart';
import 'welcome_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  final AuthService authService;
  const SplashScreen({super.key, required this.authService});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      await widget.authService.initializeSession();
    } catch (e) {
      // Ignore
    }

    if (!mounted) return;

    final user = widget.authService.currentUser;
    if (user != null) {
      if (user.isOnboarded) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => MainDashboardScreen(authService: widget.authService)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => OnboardingScreen(authService: widget.authService)),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => WelcomeScreen(authService: widget.authService)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            const Text('FitTrack AI', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
