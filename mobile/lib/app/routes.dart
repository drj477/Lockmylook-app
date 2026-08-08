// ============================================================
// LockMyLook Routes
// ============================================================

abstract final class AppRoutes {
  AppRoutes._();

  // Splash
  static const splash = '/';

  // Authentication
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  // Main
  static const home = '/home';

  // Features
  static const profiles = '/profiles';
  static const wardrobe = '/wardrobe';
  static const dressingRoom = '/dressing-room';
  static const outfits = '/outfits';
  static const journal = '/journal';
  static const settings = '/settings';

  // Premium
  static const premium = '/premium';
}
