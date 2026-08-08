class Profile {
  const Profile({required this.id, required this.name, this.avatarUrl});

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  final String id;
  final String name;
  final String? avatarUrl;
}

class ProfileCreateRequest {
  const ProfileCreateRequest({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  Map<String, dynamic> toJson() {
    return {'name': name, 'avatar_url': avatarUrl};
  }
}
