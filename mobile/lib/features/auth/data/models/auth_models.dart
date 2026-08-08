class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
}

class Account {
  const Account({required this.id, required this.email});

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(id: json['id'] as String, email: json['email'] as String);
  }

  final String id;
  final String email;
}
