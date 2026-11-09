import 'comment_insights.dart';
import 'community_reaction.dart';

class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.authorAvatarPath,
    this.parentId,
    this.isPinned = false,
    this.isBestAnswer = false,
    this.isAnonymous = false,
    this.reactionCount = 0,
    this.myReaction,
    this.reactionCounts = const {},
    this.isFlagged = false,
    this.flagReason,
    this.isSpam = false,
    this.spamReason,
    this.sentiment,
    this.mentions = const [],
  });

  final String id;
  final String postId;
  final String userId;
  final String authorName;
  final String? authorAvatarPath;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? parentId;
  final bool isPinned;
  final bool isBestAnswer;
  final bool isAnonymous;
  final int reactionCount;
  final CommunityReaction? myReaction;
  final Map<CommunityReaction, int> reactionCounts;
  final bool isFlagged;
  final String? flagReason;
  final bool isSpam;
  final String? spamReason;
  final CommentSentiment? sentiment;
  final List<String> mentions;

  String get displayAuthorName => isAnonymous ? 'Anonyme' : authorName;

  bool get isEdited =>
      updatedAt.difference(createdAt) > const Duration(seconds: 1);

  bool get hasAiWarning => isFlagged || isSpam;

  bool isOwnedBy(String currentUserId) => userId == currentUserId;

  int reactionCountOf(CommunityReaction reaction) =>
      reactionCounts[reaction] ?? 0;

  factory PostComment.fromDatabaseMap(Map<String, Object?> map) {
    return PostComment(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      userId: map['user_id'] as String,
      authorName: map['author_name'] as String,
      authorAvatarPath: map['author_avatar_path'] as String?,
      content: map['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      parentId: map['parent_id'] as String?,
      isPinned: ((map['is_pinned'] as num?)?.toInt() ?? 0) == 1,
      isBestAnswer: ((map['is_best_answer'] as num?)?.toInt() ?? 0) == 1,
      isAnonymous: ((map['is_anonymous'] as num?)?.toInt() ?? 0) == 1,
      reactionCount: (map['reaction_count'] as num?)?.toInt() ?? 0,
      myReaction: CommunityReaction.fromStorage(map['my_reaction'] as String?),
      reactionCounts: _reactionCountsFrom(map),
      isFlagged: ((map['is_flagged'] as num?)?.toInt() ?? 0) == 1,
      flagReason: map['flag_reason'] as String?,
      isSpam: ((map['is_spam'] as num?)?.toInt() ?? 0) == 1,
      spamReason: map['spam_reason'] as String?,
      sentiment: map['sentiment'] == null
          ? null
          : CommentSentiment.fromStorage(map['sentiment'] as String?),
      mentions: _listFrom(map['mentions']),
    );
  }

  PostComment copyWith({
    String? content,
    DateTime? updatedAt,
    bool? isPinned,
    bool? isBestAnswer,
    bool? isAnonymous,
    int? reactionCount,
    CommunityReaction? myReaction,
    bool clearMyReaction = false,
    Map<CommunityReaction, int>? reactionCounts,
    bool? isFlagged,
    String? flagReason,
    bool? isSpam,
    String? spamReason,
    CommentSentiment? sentiment,
    List<String>? mentions,
  }) {
    return PostComment(
      id: id,
      postId: postId,
      userId: userId,
      authorName: authorName,
      authorAvatarPath: authorAvatarPath,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parentId: parentId,
      isPinned: isPinned ?? this.isPinned,
      isBestAnswer: isBestAnswer ?? this.isBestAnswer,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      reactionCount: reactionCount ?? this.reactionCount,
      myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
      reactionCounts: reactionCounts ?? this.reactionCounts,
      isFlagged: isFlagged ?? this.isFlagged,
      flagReason: flagReason ?? this.flagReason,
      isSpam: isSpam ?? this.isSpam,
      spamReason: spamReason ?? this.spamReason,
      sentiment: sentiment ?? this.sentiment,
      mentions: mentions ?? this.mentions,
    );
  }

  static Map<CommunityReaction, int> _reactionCountsFrom(
    Map<String, Object?> map,
  ) {
    final counts = <CommunityReaction, int>{};
    for (final reaction in CommunityReaction.values) {
      final value = map['reaction_${reaction.storageValue}'];
      final count = (value as num?)?.toInt() ?? 0;
      if (count > 0) counts[reaction] = count;
    }
    return counts;
  }

  static List<String> _listFrom(Object? value) {
    if (value is! String || value.trim().isEmpty) return const [];
    return value
        .split(RegExp(r'\s+'))
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
}
