class VirtualTryOnRequest {
  const VirtualTryOnRequest({
    required this.itemIds,
  });

  final List<String> itemIds;

  Map<String, dynamic> toJson() => {
        'item_ids': itemIds,
      };
}

class VirtualTryOnResult {
  const VirtualTryOnResult({
    required this.id,
    required this.profileId,
    required this.imageUrl,
    required this.itemIds,
    required this.createdAt,
    required this.saved,
  });

  factory VirtualTryOnResult.fromJson(Map<String, dynamic> json) {
    return VirtualTryOnResult(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      imageUrl: json['image_url'] as String,
      itemIds: (json['item_ids'] as List<dynamic>)
          .map((value) => value as String)
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      saved: json['saved'] as bool? ?? false,
    );
  }

  final String id;
  final String profileId;
  final String imageUrl;
  final List<String> itemIds;
  final DateTime createdAt;
  final bool saved;
}

class VirtualTryOnSaveResult {
  const VirtualTryOnSaveResult({
    required this.id,
    required this.saved,
  });

  factory VirtualTryOnSaveResult.fromJson(Map<String, dynamic> json) {
    return VirtualTryOnSaveResult(
      id: json['id'] as String,
      saved: json['saved'] as bool,
    );
  }

  final String id;
  final bool saved;
}
