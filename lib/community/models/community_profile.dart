/// Profil local du module Publications, utilisé pour les @mentions.
///
/// Il ne remplace pas le profil utilisateur global : il ne stocke que ce qui
/// est nécessaire aux mentions du fil communautaire.
class CommunityProfile {
  const CommunityProfile({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarPath,
  });

  final String userId;
  final String username;
  final String displayName;
  final String? avatarPath;

  factory CommunityProfile.fromDatabaseMap(Map<String, Object?> map) {
    return CommunityProfile(
      userId: map['user_id'] as String,
      username: map['username'] as String,
      displayName: map['display_name'] as String,
      avatarPath: map['avatar_path'] as String?,
    );
  }
}
