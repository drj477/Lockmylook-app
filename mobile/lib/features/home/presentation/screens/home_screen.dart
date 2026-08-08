import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LockMyLook')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 72),
                const SizedBox(height: 24),
                const Text(
                  'Home',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'LockMyLook is running successfully.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.go(AppRoutes.profiles);
                    },
                    child: const Text('My Profiles'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
