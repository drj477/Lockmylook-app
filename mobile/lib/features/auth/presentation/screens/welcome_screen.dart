import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/routes.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.checkroom, size: 80),
              const SizedBox(height: 32),
              Text(
                'Welcome to LockMyLook',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Build your wardrobe, discover outfits, '
                'and find your personal style.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  context.go(AppRoutes.login);
                },
                child: const Text('Log In'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  context.go(AppRoutes.register);
                },
                child: const Text('Create an Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
