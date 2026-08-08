abstract final class ApiEndpoints {
  ApiEndpoints._();

  /// Health
  static const String health = '/health';

  /// Authentication
  static const String login = '/auth/login';
  static const String signup = '/auth/signup';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  /// Profile
  static const String profiles = '/profiles';

  /// Wardrobe
  static const String wardrobe = '/wardrobe';
  static const String wardrobeCategories = '/wardrobe/categories';
}
