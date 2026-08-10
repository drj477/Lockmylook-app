import 'package:mobile/core/constants/api_constants.dart';

class Profile {
  const Profile({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.vtoAssetUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: _resolveMediaUrl(json['avatar_url'] as String?),
      vtoAssetUrl: _resolveMediaUrl(json['vto_asset_url'] as String?),
    );
  }

  final String id;
  final String name;
  final String? avatarUrl;
  final String? vtoAssetUrl;

  static String? _resolveMediaUrl(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      return trimmed;
    }

    var path = trimmed.replaceAll('\\', '/');
    if (path.startsWith('./')) {
      path = path.substring(2);
    }
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    final base = Uri.parse(ApiConstants.baseUrl);
    final origin = Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
    );

    return origin.resolve('/$path').toString();
  }
}

class ProfileCreateRequest {
  const ProfileCreateRequest({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  Map<String, dynamic> toJson() {
    return {'name': name, 'avatar_url': avatarUrl};
  }
}
