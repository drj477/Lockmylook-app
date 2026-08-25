class CreditPurchase {
  const CreditPurchase({
    required this.id,
    required this.packageCode,
    required this.credits,
    required this.amountPaise,
    required this.currency,
    required this.status,
    this.paymentProvider,
    this.providerOrderId,
    required this.createdAt,
  });

  final String id;
  final String packageCode;
  final int credits;
  final int amountPaise;
  final String currency;
  final String status;
  final String? paymentProvider;
  final String? providerOrderId;
  final DateTime createdAt;

  factory CreditPurchase.fromJson(Map<String, dynamic> json) {
    return CreditPurchase(
      id: json['id'] as String,
      packageCode: json['package_code'] as String,
      credits: (json['credits'] as num).toInt(),
      amountPaise: (json['amount_paise'] as num).toInt(),
      currency: json['currency'] as String,
      status: json['status'] as String,
      paymentProvider: json['payment_provider'] as String?,
      providerOrderId: json['provider_order_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
