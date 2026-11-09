import 'dart:typed_data';

import 'community_reaction.dart';
import 'poll.dart';

/// Thèmes proposés lors de la création d'une publication (PUB01 / PUB05).
enum PostTheme {
  meal('repas', 'Repas'),
  nutrition('nutrition', 'Nutrition'),
  sport('sport', 'Sport'),
  progress('progres', 'Progrès');

  const PostTheme(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static PostTheme fromStorage(String value) => PostTheme.values.firstWhere(
    (theme) => theme.storageValue == value,
    orElse: () => PostTheme.meal,
  );
}

class Post {
  const Post({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.content,
    required this.theme,
    required this.createdAt,
    required this.updatedAt,
    this.authorAvatarPath,
    this.imageBytes,
    this.videoBytes,
    this.videoName,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
    this.myReaction,
    this.reactionCounts = const {},
    this.isDraft = false,
    this.isPinned = false,
    this.hashtags = const [],
    this.mentions = const [],
    this.bookmarkedByMe = false,
    this.shareCount = 0,
    this.allowAnonymousComments = false,
    this.poll,
  });

  final String id;
  final String userId;
  final String authorName;
  final String? authorAvatarPath;
  final String content;
  final Uint8List? imageBytes;
  final Uint8List? videoBytes;
  final String? videoName;
  final PostTheme theme;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Nombre total de réactions. Conservé sous ce nom pour compatibilité avec
  /// l'ancien compteur « j'aime » du module.
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final CommunityReaction? myReaction;
  final Map<CommunityReaction, int> reactionCounts;
  final bool isDraft;
  final bool isPinned;
  final List<String> hashtags;
  final List<String> mentions;
  final bool bookmarkedByMe;
  final int shareCount;
  final bool allowAnonymousComments;
  final PostPoll? poll;

  /// Nombre total d'interactions affiché dans le fil (PUB02).
  int get interactionCount => likeCount + commentCount + shareCount;

  int get reactionCount => likeCount;

  bool get isEdited =>
      updatedAt.difference(createdAt) > const Duration(seconds: 1);

  bool isOwnedBy(String currentUserId) => userId == currentUserId;

  int reactionCountOf(CommunityReaction reaction) =>
      reactionCounts[reaction] ?? 0;

  factory Post.fromDatabaseMap(Map<String, Object?> map) {
    return Post(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      authorName: map['author_name'] as String,
      authorAvatarPath: map['author_avatar_path'] as String?,
      content: map['content'] as String,
      imageBytes: _bytesFrom(map['image']),
      videoBytes: _bytesFrom(map['video']),
      videoName: map['video_name'] as String?,
      theme: PostTheme.fromStorage(map['theme'] as String),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      likeCount: (map['reaction_count'] as num?)?.toInt() ??
          (map['like_count'] as num?)?.toInt() ??
          0,
      commentCount: (map['comment_count'] as num?)?.toInt() ?? 0,
      likedByMe: map['liked_by_me'] == null
          ? CommunityReaction.fromStorage(map['my_reaction'] as String?) !=
                null
          : ((map['liked_by_me'] as num?)?.toInt() ?? 0) == 1,
      myReaction: CommunityReaction.fromStorage(map['my_reaction'] as String?),
      reactionCounts: _reactionCountsFrom(map),
      isDraft: ((map['is_draft'] as num?)?.toInt() ?? 0) == 1,
      isPinned: ((map['is_pinned'] as num?)?.toInt() ?? 0) == 1,
      hashtags: _listFrom(map['hashtags']),
      mentions: _listFrom(map['mentions']),
      bookmarkedByMe: ((map['bookmarked_by_me'] as num?)?.toInt() ?? 0) == 1,
      shareCount: (map['share_count'] as num?)?.toInt() ?? 0,
      allowAnonymousComments:
          ((map['allow_anonymous_comments'] as num?)?.toInt() ?? 0) == 1,
    );
  }

  Post copyWith({
    String? content,
    Uint8List? imageBytes,
    Uint8List? videoBytes,
    String? videoName,
    PostTheme? theme,
    DateTime? updatedAt,
    int? likeCount,
    int? commentCount,
    bool? likedByMe,
    CommunityReaction? myReaction,
    bool clearMyReaction = false,
    Map<CommunityReaction, int>? reactionCounts,
    bool? isDraft,
    bool? isPinned,
    List<String>? hashtags,
    List<String>? mentions,
    bool? bookmarkedByMe,
    int? shareCount,
    bool? allowAnonymousComments,
    PostPoll? poll,
  }) {
    return Post(
      id: id,
      userId: userId,
      authorName: authorName,
      authorAvatarPath: authorAvatarPath,
      content: content ?? this.content,
      imageBytes: imageBytes ?? this.imageBytes,
      videoBytes: videoBytes ?? this.videoBytes,
      videoName: videoName ?? this.videoName,
      theme: theme ?? this.theme,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedByMe: likedByMe ?? this.likedByMe,
      myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
      reactionCounts: reactionCounts ?? this.reactionCounts,
      isDraft: isDraft ?? this.isDraft,
      isPinned: isPinned ?? this.isPinned,
      hashtags: hashtags ?? this.hashtags,
      mentions: mentions ?? this.mentions,
      bookmarkedByMe: bookmarkedByMe ?? this.bookmarkedByMe,
      shareCount: shareCount ?? this.shareCount,
      allowAnonymousComments:
          allowAnonymousComments ?? this.allowAnonymousComments,
      poll: poll ?? this.poll,
    );
  }

  Post withPoll(PostPoll? value) {
    return Post(
      id: id,
      userId: userId,
      authorName: authorName,
      authorAvatarPath: authorAvatarPath,
      content: content,
      imageBytes: imageBytes,
      videoBytes: videoBytes,
      videoName: videoName,
      theme: theme,
      createdAt: createdAt,
      updatedAt: updatedAt,
      likeCount: likeCount,
      commentCount: commentCount,
      likedByMe: likedByMe,
      myReaction: myReaction,
      reactionCounts: reactionCounts,
      isDraft: isDraft,
      isPinned: isPinned,
      hashtags: hashtags,
      mentions: mentions,
      bookmarkedByMe: bookmarkedByMe,
      shareCount: shareCount,
      allowAnonymousComments: allowAnonymousComments,
      poll: value,
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

  static Uint8List? _bytesFrom(Object? value) {
    if (value == null) return null;
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    if (value is List) {
      return Uint8List.fromList(value.whereType<int>().toList());
    }
    return null;
  }
}
