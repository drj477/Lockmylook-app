import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/features/credits/data/models/credit_models.dart';

class CreditApi {
  CreditApi(this._apiClient);

  final ApiClient _apiClient;

  Future<CreditBalance> getBalance() async {
    final response = await _apiClient.get(ApiEndpoints.creditsBalance);
    final data = response.data as Map<String, dynamic>;
    return CreditBalance.fromJson(data);
  }
}
