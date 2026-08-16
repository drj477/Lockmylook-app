enum VirtualTryOnModel {
  replicate,
  gemini,
  geminiChat,
}

extension VirtualTryOnModelX on VirtualTryOnModel {
  String get value => switch (this) {
        VirtualTryOnModel.replicate => 'replicate',
        VirtualTryOnModel.gemini => 'gemini',
        VirtualTryOnModel.geminiChat => 'gemini_chat',
      };

  String get label => switch (this) {
        VirtualTryOnModel.replicate => 'Replicate',
        VirtualTryOnModel.gemini => 'Gemini',
        VirtualTryOnModel.geminiChat => 'Gemini Chat',
      };
}

class VirtualTryOnRequest {
  const VirtualTryOnRequest({
    required this.itemIds,
    this.model = VirtualTryOnModel.replicate,
  });

  final List<String> itemIds;
  final VirtualTryOnModel model;

  Map<String, dynamic> toJson() => {
        'item_ids': itemIds,
        'model': model.value,
      };

class VirtualTryOnResult {
  const VirtualTryOnResult({
    required this.id,
    required this.profileId,
    required this.imageUrl,
    required this.itemIds,
    required this.model,
    required this.createdAt,
    required this.saved,
  });

  factory VirtualTryOnResult.fromJson(Map<String, dynamic> json) {
    final modelValue = json['model'] as String? ?? 'replicate';

    return VirtualTryOnResult(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      imageUrl: json['image_url'] as String,
      itemIds: (json['item_ids'] as List<dynamic>)
          .map((value) => value as String)
          .toList(),
      model: VirtualTryOnModel.values.firstWhere(
        (value) => value.value == modelValue,
        orElse: () => VirtualTryOnModel.replicate,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      saved: json['saved'] as bool? ?? false,
    );
  }

  final String id;
  final String profileId;
  final String imageUrl;
  final List<String> itemIds;
  final VirtualTryOnModel model;
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
