import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/network/network_providers.dart';
import 'package:mobile/features/credits/data/credit_api.dart';

final creditApiProvider = Provider<CreditApi>((ref) {
  return CreditApi(ref.watch(apiClientProvider));
});

final creditBalanceProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(creditApiProvider).getBalance();
});
