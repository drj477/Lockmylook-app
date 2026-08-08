class WardrobeCategory {
  const WardrobeCategory({required this.id, required this.name});

  factory WardrobeCategory.fromJson(Map<String, dynamic> json) {
    return WardrobeCategory(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  final String id;
  final String name;
}

class WardrobeImage {
  const WardrobeImage({
    required this.id,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.displayOrder,
  });

  factory WardrobeImage.fromJson(Map<String, dynamic> json) {
    return WardrobeImage(
      id: json['id'] as String,
      imageUrl: json['image_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String,
      displayOrder: json['display_order'] as int,
    );
  }

  final String id;
  final String imageUrl;
  final String thumbnailUrl;
  final int displayOrder;
}

class WardrobeItem {
  const WardrobeItem({
    required this.id,
    required this.profileId,
    required this.name,
    required this.favorite,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.brand,
    this.primaryColor,
    this.secondaryColor,
    this.season,
    this.occasion,
    this.images = const [],
  });

  factory WardrobeItem.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'] as List<dynamic>? ?? const [];

    return WardrobeItem(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      primaryColor: json['primary_color'] as String?,
      secondaryColor: json['secondary_color'] as String?,
      season: json['season'] as String?,
      occasion: json['occasion'] as String?,
      favorite: json['favorite'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      category: WardrobeCategory.fromJson(
        json['category'] as Map<String, dynamic>,
      ),
      images: rawImages
          .map((item) => WardrobeImage.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String profileId;

  final String name;
  final String? brand;

  final String? primaryColor;
  final String? secondaryColor;

  final String? season;
  final String? occasion;

  final bool favorite;

  final DateTime createdAt;
  final DateTime updatedAt;

  final WardrobeCategory category;
  final List<WardrobeImage> images;

  WardrobeItem copyWith({
    String? name,
    String? brand,
    String? primaryColor,
    String? secondaryColor,
    String? season,
    String? occasion,
    bool? favorite,
  }) {
    return WardrobeItem(
      id: id,
      profileId: profileId,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      season: season ?? this.season,
      occasion: occasion ?? this.occasion,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt,
      updatedAt: updatedAt,
      category: category,
      images: images,
    );
  }
}

class WardrobeCreateRequest {
  const WardrobeCreateRequest({
    required this.categoryId,
    required this.name,
    this.brand,
    this.primaryColor,
    this.secondaryColor,
    this.season,
    this.occasion,
  });

  final String categoryId;
  final String name;
  final String? brand;
  final String? primaryColor;
  final String? secondaryColor;
  final String? season;
  final String? occasion;

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'name': name,
      'brand': brand,
      'primary_color': primaryColor,
      'secondary_color': secondaryColor,
      'season': season,
      'occasion': occasion,
    };
  }
}

class WardrobeUpdateRequest {
  const WardrobeUpdateRequest({
    this.name,
    this.brand,
    this.primaryColor,
    this.secondaryColor,
    this.season,
    this.occasion,
    this.favorite,
  });

  final String? name;
  final String? brand;
  final String? primaryColor;
  final String? secondaryColor;
  final String? season;
  final String? occasion;
  final bool? favorite;

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};

    if (name != null) {
      data['name'] = name;
    }

    if (brand != null) {
      data['brand'] = brand;
    }

    if (primaryColor != null) {
      data['primary_color'] = primaryColor;
    }

    if (secondaryColor != null) {
      data['secondary_color'] = secondaryColor;
    }

    if (season != null) {
      data['season'] = season;
    }

    if (occasion != null) {
      data['occasion'] = occasion;
    }

    if (favorite != null) {
      data['favorite'] = favorite;
    }

    return data;
  }
}
