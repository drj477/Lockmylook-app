import 'dart:math';

import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/features/credits/data/models/credit_models.dart';
import 'package:mobile/features/credits/data/models/purchase_models.dart';

class CreditApi {
  CreditApi(this._apiClient);

  final ApiClient _apiClient;

  Future<CreditBalance> getBalance() async {
    final response = await _apiClient.get(ApiEndpoints.creditsBalance);
    final data = response.data as Map<String, dynamic>;
    return CreditBalance.fromJson(data);
  }

  Future<CreditPurchase> createPurchase(String packageCode) async {
    final response = await _apiClient.post(
      ApiEndpoints.creditPurchases,
      data: {
        'package_code': packageCode,
        'idempotency_key': _newIdempotencyKey(),
      },
    );
    final data = response.data as Map<String, dynamic>;
    return CreditPurchase.fromJson(data);
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    final suffix = List.generate(16, (_) => random.nextInt(36).toRadixString(36)).join();
    return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }
}
