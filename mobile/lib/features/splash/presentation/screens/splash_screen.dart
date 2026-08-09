import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/routes.dart';
import 'package:mobile/core/theme/lockmylook_ui.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/application/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSession());
  }

  Future<void> _restoreSession() async {
    await ref.read(authControllerProvider.notifier).restoreSession();
    if (!mounted) return;
    final status = ref.read(authControllerProvider).status;
    context.go(status == AuthStatus.authenticated ? AppRoutes.home : AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [LockMyLookUi.navy, Color(0xFF050C1D)])),
        child: SafeArea(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 112, height: 112, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(15), border: Border.all(color: LockMyLookUi.coral.withAlpha(170), width: 1.5)), child: const Icon(Icons.checkroom_outlined, size: 58, color: LockMyLookUi.coral)),
              const SizedBox(height: 28),
              const Text('LOCKMYLOOK', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 8),
              const Text('Your Wardrobe. Your Style.', style: TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 42),
              SizedBox(width: 120, child: ClipRRect(borderRadius: BorderRadius.circular(20), child: const LinearProgressIndicator(minHeight: 5, color: LockMyLookUi.coral, backgroundColor: Color(0x334A5B7C)))),
            ]),
          ),
        ),
      ),
    );
  }
}
