import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final AuthService authService;
  const WelcomeScreen({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.restaurant_menu, size: 100, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              const Text(
                'Bienvenue sur\nFitTrack AI',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'L\'application intelligente pour suivre votre nutrition, vos objectifs et votre santé.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RegisterScreen(authService: authService),
                  ));
                },
                child: const Text('Créer un compte'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LoginScreen(authService: authService),
                  ));
                },
                child: const Text('Se connecter'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}