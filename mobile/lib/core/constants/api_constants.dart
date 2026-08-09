abstract final class ApiConstants {
  ApiConstants._();

  /// Backend URL
  ///
  /// Android Emulator -> host machine
  static const String baseUrl = 'http://192.168.31.25:8000/api/v1';

  /// Connection timeout
  static const Duration connectTimeout = Duration(seconds: 15);

  /// Response timeout
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Send timeout
  static const Duration sendTimeout = Duration(seconds: 15);
}
