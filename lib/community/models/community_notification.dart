enum CommunityNotificationType {
  reaction('reaction'),
  comment('comment'),
  reply('reply'),
  mention('mention'),
  commentReaction('comment_reaction'),
  pollActivity('poll_activity'),
  pollClosed('poll_closed');

  const CommunityNotificationType(this.storageValue);

  final String storageValue;

  static CommunityNotificationType fromStorage(String? value) {
    for (final type in CommunityNotificationType.values) {
      if (type.storageValue == value) return type;
    }
    return CommunityNotificationType.comment;
  }
}

class CommunityNotification {
  const CommunityNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.message,
    required this.createdAt,
    this.postId,
    this.commentId,
    this.actorId,
    this.actorName,
    this.isRead = false,
  });

  final String id;
  final String userId;
  final CommunityNotificationType type;
  final String message;
  final DateTime createdAt;
  final String? postId;
  final String? commentId;
  final String? actorId;
  final String? actorName;
  final bool isRead;

  factory CommunityNotification.fromDatabaseMap(Map<String, Object?> map) {
    return CommunityNotification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      type: CommunityNotificationType.fromStorage(map['type'] as String?),
      message: map['message'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      postId: map['post_id'] as String?,
      commentId: map['comment_id'] as String?,
      actorId: map['actor_id'] as String?,
      actorName: map['actor_name'] as String?,
      isRead: ((map['is_read'] as num?)?.toInt() ?? 0) == 1,
    );
  }
}
