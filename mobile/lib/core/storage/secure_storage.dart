import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  Future<void> saveAccessToken(String token) {
    return _storage.write(key: _accessTokenKey, value: token);
  }

  Future<void> saveRefreshToken(String token) {
    return _storage.write(key: _refreshTokenKey, value: token);
  }

  Future<String?> getAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
    ]);
  }

static const String _todayPickDateKey = 'today_pick_date';
static const String _todayPickIdsKey = 'today_pick_ids';
static const String _todayPickSeedKey = 'today_pick_seed';

Future<void> saveTodayPick({
  required String date,
  required List<String> itemIds,
  required int seed,
}) async {
  await Future.wait([
    _storage.write(key: _todayPickDateKey, value: date),
    _storage.write(
      key: _todayPickIdsKey,
      value: itemIds.join(','),
    ),
    _storage.write(
      key: _todayPickSeedKey,
      value: seed.toString(),
    ),
  ]);
}

Future<Map<String, dynamic>?> getTodayPick() async {
  final date = await _storage.read(key: _todayPickDateKey);
  final ids = await _storage.read(key: _todayPickIdsKey);
  final seed = await _storage.read(key: _todayPickSeedKey);

  if (date == null || ids == null || seed == null) {
    return null;
  }

  return {
    'date': date,
    'itemIds': ids
        .split(',')
        .where((id) => id.isNotEmpty)
        .toList(),
    'seed': int.tryParse(seed) ?? 0,
  };
}


  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }
}
