class CreditBalance {
  const CreditBalance({
    required this.balanceCredits,
    required this.balanceRupees,
  });

  final double balanceCredits;
  final double balanceRupees;

  factory CreditBalance.fromJson(Map<String, dynamic> json) {
    return CreditBalance(
      balanceCredits: (json['balance_credits'] as num).toDouble(),
      balanceRupees: (json['balance_rupees'] as num).toDouble(),
    );
  }
}
