import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/routes.dart';
import 'package:mobile/core/theme/lockmylook_ui.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [LockMyLookUi.navy, Color(0xFF071126)]),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(18), border: Border.all(color: LockMyLookUi.coral.withAlpha(170), width: 1.5)),
                  child: const Icon(Icons.checkroom_outlined, size: 58, color: LockMyLookUi.coral),
                ),
                const SizedBox(height: 28),
                const Text('LOCKMYLOOK', style: TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
                const SizedBox(height: 10),
                const Text('Your Wardrobe. Your Style.', style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 18),
                const Text('Organize your closet, build better outfits, and let AI help you style every day.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, height: 1.45, fontSize: 14)),
                const Spacer(),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => context.go(AppRoutes.register), style: ElevatedButton.styleFrom(backgroundColor: LockMyLookUi.coral, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 17)), child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.w800)))),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => context.go(AppRoutes.login), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(vertical: 17)), child: const Text('I Already Have an Account', style: TextStyle(fontWeight: FontWeight.w700)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
