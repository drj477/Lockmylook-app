class OutfitGenerateRequest {
  const OutfitGenerateRequest({
    required this.occasion,
    this.season,
    this.mood,
    this.limit = 5,
  });

  final String occasion;
  final String? season;
  final String? mood;
  final int limit;

  Map<String, dynamic> toJson() {
    return {
      'occasion': occasion,
      'season': season,
      'mood': mood,
      'limit': limit,
    };
  }
}

class OutfitItem {
  const OutfitItem({
    required this.id,
    required this.name,
    required this.category,
    required this.favorite,
    this.brand,
    this.primaryColor,
    this.secondaryColor,
    this.season,
    this.occasion,
    this.imageUrl,
  });

  factory OutfitItem.fromJson(Map<String, dynamic> json) {
    return OutfitItem(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      category: json['category'] as String,
      primaryColor: json['primary_color'] as String?,
      secondaryColor: json['secondary_color'] as String?,
      season: json['season'] as String?,
      occasion: json['occasion'] as String?,
      favorite: json['favorite'] as bool? ?? false,
      imageUrl: json['image_url'] as String?,
    );
  }

  final String id;
  final String name;
  final String? brand;
  final String category;
  final String? primaryColor;
  final String? secondaryColor;
  final String? season;
  final String? occasion;
  final bool favorite;
  final String? imageUrl;
}

class OutfitSuggestion {
  const OutfitSuggestion({
    required this.id,
    required this.score,
    required this.reason,
    required this.items,
  });

  factory OutfitSuggestion.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];

    return OutfitSuggestion(
      id: json['id'] as String,
      score: (json['score'] as num).toDouble(),
      reason: json['reason'] as String,
      items: rawItems
          .map((item) => OutfitItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final double score;
  final String reason;
  final List<OutfitItem> items;
}

class OutfitGenerateResponse {
  const OutfitGenerateResponse({
    required this.occasion,
    required this.season,
    required this.mood,
    required this.suggestions,
  });

  factory OutfitGenerateResponse.fromJson(Map<String, dynamic> json) {
    final rawSuggestions = json['suggestions'] as List<dynamic>? ?? const [];

    return OutfitGenerateResponse(
      occasion: json['occasion'] as String,
      season: json['season'] as String?,
      mood: json['mood'] as String?,
      suggestions: rawSuggestions
          .map(
            (item) => OutfitSuggestion.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final String occasion;
  final String? season;
  final String? mood;
  final List<OutfitSuggestion> suggestions;
}
