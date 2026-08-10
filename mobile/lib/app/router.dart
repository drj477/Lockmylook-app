import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/routes.dart';
import 'package:mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:mobile/features/auth/presentation/screens/welcome_screen.dart';
import 'package:mobile/features/home/presentation/screens/home_screen.dart';
import 'package:mobile/features/outfits/presentation/screens/virtual_try_on_screen.dart';
import 'package:mobile/features/profiles/presentation/screens/profiles_screen.dart';
import 'package:mobile/features/splash/presentation/screens/splash_screen.dart';
import 'package:mobile/features/wardrobe/presentation/screens/wardrobe_screen.dart';

class AppRouter {
  AppRouter._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        name: 'welcome',
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (_, _) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.profiles,
        name: 'profiles',
        builder: (_, _) => const ProfilesScreen(),
      ),
      GoRoute(
        path: AppRoutes.wardrobe,
        name: 'wardrobe',
        builder: (context, state) {
          final profileId = state.extra as String?;

          if (profileId == null || profileId.isEmpty) {
            return const Scaffold(
              body: Center(
                child: Text('A profile is required to view a wardrobe.'),
              ),
            );
          }

          return WardrobeScreen(profileId: profileId);
        },
      ),
      GoRoute(
        path: AppRoutes.outfits,
        name: 'outfits',
        builder: (context, state) {
          final profileId = state.extra as String?;

          if (profileId == null || profileId.isEmpty) {
            return const Scaffold(
              body: Center(
                child: Text('A profile is required to build an outfit.'),
              ),
            );
          }

          return VirtualTryOnScreen(profileId: profileId);
        },
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      appBar: AppBar(title: const Text('404')),
      body: Center(
        child: Text(
          'No route found:\n${state.uri}',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
