import 'dart:typed_data';

import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:uuid/uuid.dart';

import '../models/comment_insights.dart';
import '../models/community_notification.dart';
import '../models/community_profile.dart';
import '../models/community_reaction.dart';
import '../models/community_report.dart';
import '../models/poll.dart';
import '../models/post.dart';
import '../models/post_comment.dart';
import '../utils/community_formatters.dart';
import 'community_database.dart';

/// Erreur métier du module Publications (contenu vide, paternité, etc.).
class CommunityException implements Exception {
  const CommunityException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BookmarkCollection {
  const BookmarkCollection({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    this.itemCount = 0,
  });

  final String id;
  final String userId;
  final String name;
  final DateTime createdAt;
  final int itemCount;
}

/// Seul point d'accès aux données du module Publications & Commentaires.
class CommunityRepository {
  CommunityRepository({CommunityDatabase? database})
    : _database = database ?? CommunityDatabase.instance;

  final CommunityDatabase _database;
  final Uuid _uuid = const Uuid();

  static final String _reactionSelect = CommunityReaction.values
      .map(
        (reaction) =>
            '(SELECT COUNT(*) FROM post_reactions pr_${reaction.storageValue} '
            'WHERE pr_${reaction.storageValue}.post_id = p.id '
            "AND pr_${reaction.storageValue}.reaction = "
            "'${reaction.storageValue}') AS reaction_${reaction.storageValue}",
      )
      .join(',\n');

  static final String _commentReactionSelect = CommunityReaction.values
      .map(
        (reaction) =>
            '(SELECT COUNT(*) FROM comment_reactions cr_${reaction.storageValue} '
            'WHERE cr_${reaction.storageValue}.comment_id = c.id '
            "AND cr_${reaction.storageValue}.reaction = "
            "'${reaction.storageValue}') AS reaction_${reaction.storageValue}",
      )
      .join(',\n');

  static final String _postSelect = '''
    SELECT p.*,
      (SELECT COUNT(*) FROM post_reactions pr WHERE pr.post_id = p.id)
        AS reaction_count,
      (SELECT reaction FROM post_reactions mr
        WHERE mr.post_id = p.id AND mr.user_id = ?) AS my_reaction,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id)
        AS comment_count,
      EXISTS(SELECT 1 FROM bookmarks b
        WHERE b.post_id = p.id AND b.user_id = ?) AS bookmarked_by_me,
      (SELECT COUNT(*) FROM post_shares s WHERE s.post_id = p.id)
        AS share_count,
      $_reactionSelect
    FROM posts p
  ''';

  static final String _commentSelect = '''
    SELECT c.*,
      (SELECT COUNT(*) FROM comment_reactions cr WHERE cr.comment_id = c.id)
        AS reaction_count,
      (SELECT reaction FROM comment_reactions mcr
        WHERE mcr.comment_id = c.id AND mcr.user_id = ?) AS my_reaction,
      $_commentReactionSelect
    FROM comments c
  ''';

  static const String _reportSelect = '''
    SELECT r.*,
      CASE WHEN r.target_type = 'post'
        THEN (SELECT content FROM posts WHERE id = r.target_id)
        ELSE (SELECT content FROM comments WHERE id = r.target_id)
      END AS target_preview,
      CASE WHEN r.target_type = 'post'
        THEN (SELECT user_id FROM posts WHERE id = r.target_id)
        ELSE (SELECT user_id FROM comments WHERE id = r.target_id)
      END AS target_owner_id,
      CASE WHEN r.target_type = 'post'
        THEN (SELECT user_id FROM posts WHERE id = r.target_id)
        ELSE (
          SELECT p.user_id FROM comments c
          JOIN posts p ON p.id = c.post_id
          WHERE c.id = r.target_id
        )
      END AS post_owner_id
    FROM reports r
  ''';

  static const String _flagSelect = '''
    SELECT f.*,
      CASE WHEN f.target_type = 'post'
        THEN (SELECT content FROM posts WHERE id = f.target_id)
        ELSE (SELECT content FROM comments WHERE id = f.target_id)
      END AS target_preview
    FROM content_flags f
  ''';

  // --- PUBLICATIONS (PUB01, PUB02, PUB03, PUB05) ---

  /// Fil d'actualité, du plus récent au plus ancien, avec le nombre
  /// d'interactions et le thème optionnel (PUB02 / PUB05).
  Future<List<Post>> getFeed({
    required String currentUserId,
    PostTheme? theme,
  }) async {
    final db = await _database.database;
    final whereClause = <String>['p.is_draft = 0'];
    final args = <Object?>[currentUserId, currentUserId];
    if (theme != null) {
      whereClause.add('p.theme = ?');
      args.add(theme.storageValue);
    }

    final rows = await db.rawQuery('''
      $_postSelect
      WHERE ${whereClause.join(' AND ')}
      ORDER BY p.is_pinned DESC, p.created_at DESC, p.rowid DESC
    ''', args);

    final posts = rows.map(Post.fromDatabaseMap).toList();
    return _attachPolls(posts, currentUserId);
  }

  Future<List<Post>> getDrafts({required String userId}) async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      $_postSelect
      WHERE p.is_draft = 1 AND p.user_id = ?
      ORDER BY p.updated_at DESC, p.rowid DESC
    ''', [userId, userId, userId]);
    return _attachPolls(rows.map(Post.fromDatabaseMap).toList(), userId);
  }

  Future<Post?> getPost(String postId, String currentUserId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      $_postSelect
      WHERE p.id = ?
      LIMIT 1
      ''',
      [currentUserId, currentUserId, postId],
    );
    if (rows.isEmpty) return null;
    final posts = await _attachPolls(
      [Post.fromDatabaseMap(rows.first)],
      currentUserId,
    );
    return posts.first;
  }

  Future<Post> createPost({
    required String userId,
    required String authorName,
    String? authorAvatarPath,
    required String content,
    required PostTheme theme,
    Uint8List? imageBytes,
    Uint8List? videoBytes,
    String? videoName,
    bool isDraft = false,
    bool allowAnonymousComments = false,
    String? pollQuestion,
    List<String>? pollOptions,
    DateTime? pollEndsAt,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const CommunityException(
        'Le texte de la publication ne peut pas être vide.',
      );
    }

    final now = DateTime.now();
    final postId = _uuid.v4();
    final db = await _database.database;
    await _upsertProfile(
      userId: userId,
      displayName: authorName,
      avatarPath: authorAvatarPath,
    );

    final hashtags = extractHashtags(trimmed);
    final mentions = extractMentions(trimmed);

    await db.insert('posts', {
      'id': postId,
      'user_id': userId,
      'author_name': authorName,
      'author_avatar_path': authorAvatarPath,
      'content': trimmed,
      'image': imageBytes,
      'video': videoBytes,
      'video_name': videoName,
      'theme': theme.storageValue,
      'is_draft': isDraft ? 1 : 0,
      'is_pinned': 0,
      'hashtags': hashtags.join(' '),
      'mentions': mentions.join(' '),
      'allow_anonymous_comments': allowAnonymousComments ? 1 : 0,
      'created_at': now.millisecondsSinceEpoch,
      'updated_at': now.millisecondsSinceEpoch,
    });

    await _createPollIfNeeded(
      postId: postId,
      question: pollQuestion,
      options: pollOptions,
      endsAt: pollEndsAt,
    );
    await _notifyMentions(
      mentions: mentions,
      actorId: userId,
      actorName: authorName,
      postId: postId,
      type: CommunityNotificationType.mention,
      context: 'une publication',
    );

    final created = await getPost(postId, userId);
    if (created == null) {
      throw const CommunityException('Publication introuvable après création.');
    }
    return created;
  }

  /// RG08 : la clause `user_id = ?` garantit qu'un utilisateur ne peut
  /// modifier que ses propres publications.
  Future<Post> updatePost({
    required String postId,
    required String userId,
    required String content,
    required PostTheme theme,
    bool? isDraft,
    bool? allowAnonymousComments,
    Uint8List? imageBytes,
    bool clearImage = false,
    Uint8List? videoBytes,
    String? videoName,
    bool clearVideo = false,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const CommunityException(
        'Le texte de la publication ne peut pas être vide.',
      );
    }

    final hashtags = extractHashtags(trimmed);
    final mentions = extractMentions(trimmed);
    final update = <String, Object?>{
      'content': trimmed,
      'theme': theme.storageValue,
      'hashtags': hashtags.join(' '),
      'mentions': mentions.join(' '),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (isDraft != null) update['is_draft'] = isDraft ? 1 : 0;
    if (allowAnonymousComments != null) {
      update['allow_anonymous_comments'] = allowAnonymousComments ? 1 : 0;
    }
    if (clearImage) update['image'] = null;
    if (imageBytes != null) update['image'] = imageBytes;
    if (clearVideo) {
      update['video'] = null;
      update['video_name'] = null;
    }
    if (videoBytes != null) {
      update['video'] = videoBytes;
      update['video_name'] = videoName;
    }

    final db = await _database.database;
    final updated = await db.update(
      'posts',
      update,
      where: 'id = ? AND user_id = ?',
      whereArgs: [postId, userId],
    );
    if (updated == 0) {
      throw const CommunityException(
        'Vous ne pouvez modifier que vos propres publications.',
      );
    }

    final post = await getPost(postId, userId);
    if (post == null) {
      throw const CommunityException('Publication introuvable.');
    }
    await _notifyMentions(
      mentions: mentions,
      actorId: userId,
      actorName: post.authorName,
      postId: postId,
      type: CommunityNotificationType.mention,
      context: 'une publication',
    );
    return post;
  }

  Future<void> publishDraft({
    required String postId,
    required String userId,
  }) async {
    final db = await _database.database;
    final updated = await db.update(
      'posts',
      {'is_draft': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ? AND user_id = ?',
      whereArgs: [postId, userId],
    );
    if (updated == 0) {
      throw const CommunityException(
        'Vous ne pouvez publier que vos propres brouillons.',
      );
    }
  }

  /// RG08 : suppression réservée au propriétaire de la publication.
  Future<void> deletePost({
    required String postId,
    required String userId,
  }) async {
    final db = await _database.database;
    final owner = await db.query(
      'posts',
      columns: ['user_id'],
      where: 'id = ?',
      whereArgs: [postId],
      limit: 1,
    );
    if (owner.isEmpty || owner.first['user_id'] != userId) {
      throw const CommunityException(
        'Vous ne pouvez supprimer que vos propres publications.',
      );
    }

    await db.transaction((txn) async {
      await txn.delete(
        'reports',
        where: 'target_type = ? AND target_id = ?',
        whereArgs: ['post', postId],
      );
      await txn.delete(
        'content_flags',
        where: 'target_type = ? AND target_id = ?',
        whereArgs: ['post', postId],
      );
      await txn.delete(
        'comments',
        where: 'post_id = ?',
        whereArgs: [postId],
      );
      await txn.delete('posts', where: 'id = ?', whereArgs: [postId]);
    });
  }

  /// Épingle une publication. Seul son propriétaire peut la épingler.
  Future<bool> togglePinPost({
    required String postId,
    required String userId,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'posts',
      columns: ['is_pinned'],
      where: 'id = ? AND user_id = ?',
      whereArgs: [postId, userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const CommunityException(
        'Vous ne pouvez épingler que vos propres publications.',
      );
    }
    final next = ((rows.first['is_pinned'] as num?)?.toInt() ?? 0) == 1
        ? 0
        : 1;
    await db.update(
      'posts',
      {'is_pinned': next, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ? AND user_id = ?',
      whereArgs: [postId, userId],
    );
    return next == 1;
  }

  Future<void> registerShare({
    required String postId,
    required String userId,
  }) async {
    final db = await _database.database;
    await db.insert('post_shares', {
      'post_id': postId,
      'user_id': userId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // --- RÉACTIONS ---

  /// Ajoute, remplace ou retire la réaction de l'utilisateur.
  Future<CommunityReaction?> toggleReaction({
    required String postId,
    required String userId,
    required CommunityReaction reaction,
    String? actorName,
  }) async {
    final db = await _database.database;
    final postRows = await db.query(
      'posts',
      columns: ['user_id'],
      where: 'id = ?',
      whereArgs: [postId],
      limit: 1,
    );
    if (postRows.isEmpty) {
      throw const CommunityException('Publication introuvable.');
    }

    final existing = await db.query(
      'post_reactions',
      columns: ['reaction'],
      where: 'post_id = ? AND user_id = ?',
      whereArgs: [postId, userId],
      limit: 1,
    );
    final alreadySame =
        existing.isNotEmpty &&
        existing.first['reaction'] == reaction.storageValue;

    if (alreadySame) {
      await db.delete(
        'post_reactions',
        where: 'post_id = ? AND user_id = ?',
        whereArgs: [postId, userId],
      );
      if (reaction == CommunityReaction.like) {
        await db.delete(
          'post_likes',
          where: 'post_id = ? AND user_id = ?',
          whereArgs: [postId, userId],
        );
      }
      return null;
    }

    await db.insert(
      'post_reactions',
      {
        'post_id': postId,
        'user_id': userId,
        'reaction': reaction.storageValue,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (reaction == CommunityReaction.like) {
      await db.insert(
        'post_likes',
        {
          'post_id': postId,
          'user_id': userId,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.delete(
        'post_likes',
        where: 'post_id = ? AND user_id = ?',
        whereArgs: [postId, userId],
      );
    }

    final ownerId = postRows.first['user_id'] as String;
    if (actorName != null && ownerId != userId) {
      await _createNotification(
        userId: ownerId,
        type: CommunityNotificationType.reaction,
        message: '$actorName a réagi ${reaction.emoji} à votre publication.',
        postId: postId,
        actorId: userId,
        actorName: actorName,
      );
    }
    return reaction;
  }

  /// Compatibilité avec l'ancien « j'aime » du module.
  Future<bool> toggleLike({
    required String postId,
    required String userId,
  }) async {
    final result = await toggleReaction(
      postId: postId,
      userId: userId,
      reaction: CommunityReaction.like,
    );
    return result == CommunityReaction.like;
  }

  Future<List<ReactionEntry>> getReactions(String postId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT r.user_id, r.reaction, COALESCE(p.display_name, 'Membre') AS name
      FROM post_reactions r
      LEFT JOIN community_profiles p ON p.user_id = r.user_id
      WHERE r.post_id = ?
      ORDER BY r.created_at DESC
      ''',
      [postId],
    );
    return rows
        .map(
          (row) => ReactionEntry(
            userId: row['user_id'] as String,
            userName: (row['name'] as String?) ?? 'Membre',
            reaction:
                CommunityReaction.fromStorage(row['reaction'] as String?) ??
                CommunityReaction.like,
          ),
        )
        .toList();
  }

  Future<CommunityReaction?> toggleCommentReaction({
    required String commentId,
    required String userId,
    required CommunityReaction reaction,
    String? actorName,
  }) async {
    final db = await _database.database;
    final commentRows = await db.query(
      'comments',
      columns: ['user_id', 'post_id', 'is_anonymous'],
      where: 'id = ?',
      whereArgs: [commentId],
      limit: 1,
    );
    if (commentRows.isEmpty) {
      throw const CommunityException('Commentaire introuvable.');
    }

    final existing = await db.query(
      'comment_reactions',
      columns: ['reaction'],
      where: 'comment_id = ? AND user_id = ?',
      whereArgs: [commentId, userId],
      limit: 1,
    );
    final alreadySame =
        existing.isNotEmpty &&
        existing.first['reaction'] == reaction.storageValue;

    if (alreadySame) {
      await db.delete(
        'comment_reactions',
        where: 'comment_id = ? AND user_id = ?',
        whereArgs: [commentId, userId],
      );
      return null;
    }

    await db.insert(
      'comment_reactions',
      {
        'comment_id': commentId,
        'user_id': userId,
        'reaction': reaction.storageValue,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final ownerId = commentRows.first['user_id'] as String;
    if (actorName != null && ownerId != userId) {
      await _createNotification(
        userId: ownerId,
        type: CommunityNotificationType.commentReaction,
        message: '$actorName a réagi ${reaction.emoji} à votre commentaire.',
        postId: commentRows.first['post_id'] as String?,
        commentId: commentId,
        actorId: userId,
        actorName: actorName,
      );
    }
    return reaction;
  }

  Future<List<ReactionEntry>> getCommentReactions(String commentId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT r.user_id, r.reaction, COALESCE(p.display_name, 'Membre') AS name
      FROM comment_reactions r
      LEFT JOIN community_profiles p ON p.user_id = r.user_id
      WHERE r.comment_id = ?
      ORDER BY r.created_at DESC
      ''',
      [commentId],
    );
    return rows
        .map(
          (row) => ReactionEntry(
            userId: row['user_id'] as String,
            userName: (row['name'] as String?) ?? 'Membre',
            reaction:
                CommunityReaction.fromStorage(row['reaction'] as String?) ??
                CommunityReaction.like,
          ),
        )
        .toList();
  }

  // --- COMMENTAIRES (PUB04) ---

  Future<List<PostComment>> getComments(
    String postId, {
    String currentUserId = '',
  }) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      $_commentSelect
      WHERE c.post_id = ?
      ORDER BY c.created_at ASC, c.rowid ASC
      ''',
      [currentUserId, postId],
    );
    return rows.map(PostComment.fromDatabaseMap).toList();
  }

  Future<PostComment> addComment({
    required String postId,
    required String userId,
    required String authorName,
    String? authorAvatarPath,
    required String content,
    String? parentId,
    bool isAnonymous = false,
    CommentSentiment? sentiment,
    bool isFlagged = false,
    String? flagReason,
    bool isSpam = false,
    String? spamReason,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const CommunityException(
        'Le commentaire ne peut pas être vide.',
      );
    }

    final db = await _database.database;
    final postRows = await db.query(
      'posts',
      columns: ['user_id'],
      where: 'id = ?',
      whereArgs: [postId],
      limit: 1,
    );
    if (postRows.isEmpty) {
      throw const CommunityException('Publication introuvable.');
    }

    if (parentId != null) {
      final parentRows = await db.query(
        'comments',
        columns: ['post_id'],
        where: 'id = ?',
        whereArgs: [parentId],
        limit: 1,
      );
      if (parentRows.isEmpty || parentRows.first['post_id'] != postId) {
        throw const CommunityException(
          'Le commentaire auquel vous répondez est introuvable.',
        );
      }
    }

    await _upsertProfile(
      userId: userId,
      displayName: authorName,
      avatarPath: authorAvatarPath,
    );

    final now = DateTime.now();
    final commentId = _uuid.v4();
    final mentions = extractMentions(trimmed);
    await db.insert('comments', {
      'id': commentId,
      'post_id': postId,
      'parent_id': parentId,
      'user_id': userId,
      'author_name': authorName,
      'author_avatar_path': authorAvatarPath,
      'content': trimmed,
      'is_pinned': 0,
      'is_best_answer': 0,
      'is_anonymous': isAnonymous ? 1 : 0,
      'sentiment': sentiment?.name,
      'is_flagged': isFlagged ? 1 : 0,
      'flag_reason': flagReason,
      'is_spam': isSpam ? 1 : 0,
      'spam_reason': spamReason,
      'mentions': mentions.join(' '),
      'created_at': now.millisecondsSinceEpoch,
      'updated_at': now.millisecondsSinceEpoch,
    });

    final actorName = isAnonymous ? 'Quelqu\'un' : authorName;
    if (parentId != null) {
      final parent = await db.query(
        'comments',
        columns: ['user_id', 'is_anonymous'],
        where: 'id = ?',
        whereArgs: [parentId],
        limit: 1,
      );
      if (parent.isNotEmpty && parent.first['user_id'] != userId) {
        final targetAnonymous =
            ((parent.first['is_anonymous'] as num?)?.toInt() ?? 0) == 1;
        await _createNotification(
          userId: parent.first['user_id'] as String,
          type: CommunityNotificationType.reply,
          message: '$actorName a répondu à votre commentaire.',
          postId: postId,
          commentId: commentId,
          actorId: userId,
          actorName: targetAnonymous ? 'Quelqu\'un' : actorName,
        );
      }
    } else {
      final ownerId = postRows.first['user_id'] as String;
      if (ownerId != userId) {
        await _createNotification(
          userId: ownerId,
          type: CommunityNotificationType.comment,
          message: '$actorName a commenté votre publication.',
          postId: postId,
          commentId: commentId,
          actorId: userId,
          actorName: actorName,
        );
      }
    }

    await _notifyMentions(
      mentions: mentions,
      actorId: userId,
      actorName: actorName,
      postId: postId,
      commentId: commentId,
      type: CommunityNotificationType.mention,
      context: 'un commentaire',
    );

    final rows = await db.query(
      'comments',
      where: 'id = ?',
      whereArgs: [commentId],
      limit: 1,
    );
    return PostComment.fromDatabaseMap(rows.first);
  }

  /// RG08 : modification réservée à l'auteur du commentaire.
  Future<PostComment> updateComment({
    required String commentId,
    required String userId,
    required String content,
    CommentSentiment? sentiment,
    bool? isFlagged,
    String? flagReason,
    bool? isSpam,
    String? spamReason,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const CommunityException(
        'Le commentaire ne peut pas être vide.',
      );
    }

    final update = <String, Object?>{
      'content': trimmed,
      'mentions': extractMentions(trimmed).join(' '),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (sentiment != null) update['sentiment'] = sentiment.name;
    if (isFlagged != null) update['is_flagged'] = isFlagged ? 1 : 0;
    if (flagReason != null) update['flag_reason'] = flagReason;
    if (isSpam != null) update['is_spam'] = isSpam ? 1 : 0;
    if (spamReason != null) update['spam_reason'] = spamReason;

    final db = await _database.database;
    final updated = await db.update(
      'comments',
      update,
      where: 'id = ? AND user_id = ?',
      whereArgs: [commentId, userId],
    );
    if (updated == 0) {
      throw const CommunityException(
        'Vous ne pouvez modifier que vos propres commentaires.',
      );
    }

    final rows = await db.query(
      'comments',
      where: 'id = ?',
      whereArgs: [commentId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const CommunityException('Commentaire introuvable.');
    }
    return PostComment.fromDatabaseMap(rows.first);
  }

  /// RG08 : suppression réservée à l'auteur du commentaire.
  Future<void> deleteComment({
    required String commentId,
    required String userId,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'comments',
      columns: ['user_id'],
      where: 'id = ?',
      whereArgs: [commentId],
      limit: 1,
    );
    if (rows.isEmpty || rows.first['user_id'] != userId) {
      throw const CommunityException(
        'Vous ne pouvez supprimer que vos propres commentaires.',
      );
    }
    await db.transaction((txn) async {
      await txn.delete(
        'reports',
        where: 'target_type = ? AND target_id = ?',
        whereArgs: ['comment', commentId],
      );
      await txn.delete(
        'content_flags',
        where: 'target_type = ? AND target_id = ?',
        whereArgs: ['comment', commentId],
      );
      await txn.delete(
        'comments',
        where: 'id = ?',
        whereArgs: [commentId],
      );
    });
  }

  /// Épinglage réservé au propriétaire de la publication.
  Future<bool> togglePinComment({
    required String commentId,
    required String postId,
    required String userId,
  }) async {
    final db = await _database.database;
    final postRows = await db.query(
      'posts',
      columns: ['user_id'],
      where: 'id = ?',
      whereArgs: [postId],
      limit: 1,
    );
    if (postRows.isEmpty || postRows.first['user_id'] != userId) {
      throw const CommunityException(
        'Seul le propriétaire de la publication peut épingler un commentaire.',
      );
    }
    final rows = await db.query(
      'comments',
      columns: ['is_pinned'],
      where: 'id = ? AND post_id = ?',
      whereArgs: [commentId, postId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const CommunityException('Commentaire introuvable.');
    }
    final next = ((rows.first['is_pinned'] as num?)?.toInt() ?? 0) == 1
        ? 0
        : 1;
    await db.transaction((txn) async {
      if (next == 1) {
        await txn.update(
          'comments',
          {'is_pinned': 0},
          where: 'post_id = ?',
          whereArgs: [postId],
        );
      }
      await txn.update(
        'comments',
        {'is_pinned': next},
        where: 'id = ?',
        whereArgs: [commentId],
      );
    });
    return next == 1;
  }

  /// Meilleure réponse réservée au propriétaire de la publication.
  Future<bool> toggleBestAnswer({
    required String commentId,
    required String postId,
    required String userId,
  }) async {
    final db = await _database.database;
    final postRows = await db.query(
      'posts',
      columns: ['user_id'],
      where: 'id = ?',
      whereArgs: [postId],
      limit: 1,
    );
    if (postRows.isEmpty || postRows.first['user_id'] != userId) {
      throw const CommunityException(
        'Seul le propriétaire de la publication peut choisir la meilleure '
        'réponse.',
      );
    }
    final rows = await db.query(
      'comments',
      columns: ['is_best_answer'],
      where: 'id = ? AND post_id = ?',
      whereArgs: [commentId, postId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const CommunityException('Commentaire introuvable.');
    }
    final next = ((rows.first['is_best_answer'] as num?)?.toInt() ?? 0) == 1
        ? 0
        : 1;
    await db.transaction((txn) async {
      await txn.update(
        'comments',
        {'is_best_answer': 0},
        where: 'post_id = ?',
        whereArgs: [postId],
      );
      if (next == 1) {
        await txn.update(
          'comments',
          {'is_best_answer': 1},
          where: 'id = ?',
          whereArgs: [commentId],
        );
      }
    });
    return next == 1;
  }

  // --- SONDAGES ---

  Future<void> votePoll({
    required String postId,
    required String optionId,
    required String userId,
    String? actorName,
  }) async {
    final db = await _database.database;
    final pollRows = await db.query(
      'polls',
      where: 'post_id = ?',
      whereArgs: [postId],
      limit: 1,
    );
    if (pollRows.isEmpty) {
      throw const CommunityException('Sondage introuvable.');
    }
    final poll = pollRows.first;
    final endsAt = poll['ends_at'] as int?;
    if (endsAt != null && DateTime.now().millisecondsSinceEpoch > endsAt) {
      throw const CommunityException('Ce sondage est terminé.');
    }

    final optionRows = await db.query(
      'poll_options',
      columns: ['poll_id'],
      where: 'id = ?',
      whereArgs: [optionId],
      limit: 1,
    );
    if (optionRows.isEmpty || optionRows.first['poll_id'] != poll['id']) {
      throw const CommunityException('Option de sondage invalide.');
    }

    await db.insert(
      'poll_votes',
      {
        'poll_id': poll['id'] as String,
        'option_id': optionId,
        'user_id': userId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final postRows = await db.query(
      'posts',
      columns: ['user_id'],
      where: 'id = ?',
      whereArgs: [postId],
      limit: 1,
    );
    if (postRows.isNotEmpty) {
      final ownerId = postRows.first['user_id'] as String;
      if (actorName != null && ownerId != userId) {
        await _createNotification(
          userId: ownerId,
          type: CommunityNotificationType.pollActivity,
          message:
              '$actorName a voté au sondage « ${poll['question']} ».',
          postId: postId,
          actorId: userId,
          actorName: actorName,
        );
      }
    }
  }

  // --- ENREGISTREMENTS & COLLECTIONS ---

  Future<bool> toggleBookmark({
    required String postId,
    required String userId,
    String? collectionId,
  }) async {
    final db = await _database.database;
    final existing = await db.query(
      'bookmarks',
      columns: ['post_id'],
      where: 'post_id = ? AND user_id = ?',
      whereArgs: [postId, userId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.delete(
        'bookmarks',
        where: 'post_id = ? AND user_id = ?',
        whereArgs: [postId, userId],
      );
      return false;
    }
    await db.insert('bookmarks', {
      'user_id': userId,
      'post_id': postId,
      'collection_id': collectionId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return true;
  }

  Future<List<Post>> getBookmarkedPosts({
    required String currentUserId,
    String? collectionId,
  }) async {
    final db = await _database.database;
    final args = <Object?>[currentUserId, currentUserId, currentUserId];
    final collectionClause = collectionId == null
        ? ''
        : 'AND b.collection_id = ?';
    if (collectionId != null) args.add(collectionId);
    final rows = await db.rawQuery('''
      $_postSelect
      JOIN bookmarks b ON b.post_id = p.id AND b.user_id = ?
      WHERE p.is_draft = 0 $collectionClause
      ORDER BY b.created_at DESC, p.rowid DESC
    ''', args);
    return _attachPolls(rows.map(Post.fromDatabaseMap).toList(), currentUserId);
  }

  Future<List<BookmarkCollection>> getCollections(String userId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT c.*,
        (SELECT COUNT(*) FROM bookmarks b
          WHERE b.collection_id = c.id AND b.user_id = c.user_id) AS item_count
      FROM bookmark_collections c
      WHERE c.user_id = ?
      ORDER BY c.created_at ASC
      ''',
      [userId],
    );
    return rows
        .map(
          (row) => BookmarkCollection(
            id: row['id'] as String,
            userId: row['user_id'] as String,
            name: row['name'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['created_at'] as int,
            ),
            itemCount: (row['item_count'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  Future<BookmarkCollection> createCollection({
    required String userId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const CommunityException('Le nom de la collection est requis.');
    }
    final now = DateTime.now();
    final collection = BookmarkCollection(
      id: _uuid.v4(),
      userId: userId,
      name: trimmed,
      createdAt: now,
    );
    final db = await _database.database;
    await db.insert('bookmark_collections', {
      'id': collection.id,
      'user_id': userId,
      'name': trimmed,
      'created_at': now.millisecondsSinceEpoch,
    });
    return collection;
  }

  Future<void> deleteCollection({
    required String collectionId,
    required String userId,
  }) async {
    final db = await _database.database;
    final deleted = await db.delete(
      'bookmark_collections',
      where: 'id = ? AND user_id = ?',
      whereArgs: [collectionId, userId],
    );
    if (deleted == 0) {
      throw const CommunityException('Collection introuvable.');
    }
  }

  // --- SIGNALEMENTS, FLAGS IA & MODÉRATION PAR LE PROPRIÉTAIRE ---

  Future<void> reportContent({
    required ReportTargetType targetType,
    required String targetId,
    required String reporterId,
    String? reporterName,
    required ReportReason reason,
    String? details,
  }) async {
    final db = await _database.database;
    final target = targetType == ReportTargetType.post
        ? await db.query(
            'posts',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [targetId],
            limit: 1,
          )
        : await db.query(
            'comments',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [targetId],
            limit: 1,
          );
    if (target.isEmpty) {
      throw const CommunityException('Contenu introuvable.');
    }
    await db.insert('reports', {
      'id': _uuid.v4(),
      'target_type': targetType.storageValue,
      'target_id': targetId,
      'reporter_id': reporterId,
      'reporter_name': reporterName,
      'reason': reason.storageValue,
      'details': details?.trim() ?? '',
      'status': ReportStatus.pending.storageValue,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<ContentReport>> getMyReports(String userId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT * FROM ($_reportSelect) WHERE reporter_id = ? '
      'ORDER BY created_at DESC',
      [userId],
    );
    return rows.map(ContentReport.fromDatabaseMap).toList();
  }

  Future<List<ContentReport>> getReportsOnMyContent(String userId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT * FROM ($_reportSelect) '
      'WHERE target_owner_id = ? OR post_owner_id = ? '
      'ORDER BY created_at DESC',
      [userId, userId],
    );
    return rows.map(ContentReport.fromDatabaseMap).toList();
  }

  Future<void> resolveReport({
    required String reportId,
    required String userId,
    required ReportStatus status,
    String? note,
  }) async {
    if (status == ReportStatus.pending) {
      throw const CommunityException('Statut de signalement invalide.');
    }
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT * FROM ($_reportSelect) WHERE id = ? LIMIT 1',
      [reportId],
    );
    if (rows.isEmpty) {
      throw const CommunityException('Signalement introuvable.');
    }
    final report = ContentReport.fromDatabaseMap(rows.first);
    if (report.targetOwnerId != userId && report.targetPreview.isEmpty) {
      throw const CommunityException(
        'Vous ne pouvez traiter que les signalements liés à votre contenu.',
      );
    }
    final belongsToUser = await _ownsReportedContent(
      report.targetType,
      report.targetId,
      userId,
    );
    if (!belongsToUser) {
      throw const CommunityException(
        'Vous ne pouvez traiter que les signalements liés à votre contenu.',
      );
    }

    await db.update(
      'reports',
      {
        'status': status.storageValue,
        'resolution_note': note?.trim() ?? '',
        'reviewed_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [reportId],
    );
    await _recordModerationAction(
      actorId: userId,
      targetType: report.targetType,
      targetId: report.targetId,
      action: status == ReportStatus.reviewed
          ? 'signalement examiné'
          : 'signalement ignoré',
      note: note,
    );
  }

  Future<List<ContentFlag>> getFlagsForMyContent(String userId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT * FROM ($_flagSelect) '
      'WHERE owner_id = ? OR post_owner_id = ? '
      'ORDER BY created_at DESC',
      [userId, userId],
    );
    return rows.map(ContentFlag.fromDatabaseMap).toList();
  }

  Future<ContentFlag> saveContentFlag({
    required ReportTargetType targetType,
    required String targetId,
    required String ownerId,
    String? postOwnerId,
    required String category,
    required String explanation,
    required AiSource source,
  }) async {
    final db = await _database.database;
    final flag = ContentFlag(
      id: _uuid.v4(),
      targetType: targetType,
      targetId: targetId,
      ownerId: ownerId,
      postOwnerId: postOwnerId,
      category: category,
      explanation: explanation,
      source: source,
      createdAt: DateTime.now(),
    );
    await db.insert('content_flags', {
      'id': flag.id,
      'target_type': targetType.storageValue,
      'target_id': targetId,
      'owner_id': ownerId,
      'post_owner_id': postOwnerId,
      'category': category,
      'explanation': explanation,
      'source': source.name,
      'status': ContentFlagStatus.pending.storageValue,
      'created_at': flag.createdAt.millisecondsSinceEpoch,
    });
    return flag;
  }

  Future<void> dismissFlag({
    required String flagId,
    required String userId,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'content_flags',
      where: 'id = ?',
      whereArgs: [flagId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const CommunityException('Signalement IA introuvable.');
    }
    final flag = ContentFlag.fromDatabaseMap(rows.first);
    final ownsPost = flag.postOwnerId == userId;
    final ownsContent = flag.ownerId == userId;
    if (!ownsPost && !ownsContent) {
      throw const CommunityException(
        'Vous ne pouvez traiter que les alertes liées à votre contenu.',
      );
    }
    await db.update(
      'content_flags',
      {'status': ContentFlagStatus.dismissed.storageValue},
      where: 'id = ?',
      whereArgs: [flagId],
    );
    await _recordModerationAction(
      actorId: userId,
      targetType: flag.targetType,
      targetId: flag.targetId,
      action: 'alerte IA ignorée',
      note: flag.explanation,
    );
  }

  Future<List<ModerationAction>> getModerationHistory(String userId) async {
    final db = await _database.database;
    final rows = await db.query(
      'moderation_actions',
      where: 'actor_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 100,
    );
    return rows.map(ModerationAction.fromDatabaseMap).toList();
  }

  // --- NOTIFICATIONS DU MODULE ---

  Future<List<CommunityNotification>> getNotifications(String userId) async {
    final db = await _database.database;
    final rows = await db.query(
      'community_notifications',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 80,
    );
    return rows.map(CommunityNotification.fromDatabaseMap).toList();
  }

  Future<int> getUnreadNotificationCount(String userId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM community_notifications '
      'WHERE user_id = ? AND is_read = 0',
      [userId],
    );
    return (rows.first['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markNotificationRead(String notificationId) async {
    final db = await _database.database;
    await db.update(
      'community_notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  Future<void> markAllNotificationsRead(String userId) async {
    final db = await _database.database;
    await db.update(
      'community_notifications',
      {'is_read': 1},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Crée les notifications de clôture des sondages de l'utilisateur.
  Future<void> checkPollClosures(String userId) async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      '''
      SELECT p.id, p.post_id, p.question
      FROM polls p
      WHERE p.ends_at IS NOT NULL AND p.ends_at <= ?
        AND (
          EXISTS(SELECT 1 FROM posts po
            WHERE po.id = p.post_id AND po.user_id = ?)
          OR EXISTS(SELECT 1 FROM poll_votes v
            WHERE v.poll_id = p.id AND v.user_id = ?)
        )
      ''',
      [now, userId, userId],
    );
    for (final row in rows) {
      final postId = row['post_id'] as String;
      final existing = await db.query(
        'community_notifications',
        columns: ['id'],
        where: 'user_id = ? AND type = ? AND post_id = ?',
        whereArgs: [
          userId,
          CommunityNotificationType.pollClosed.storageValue,
          postId,
        ],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;
      await _createNotification(
        userId: userId,
        type: CommunityNotificationType.pollClosed,
        message: 'Le sondage « ${row['question']} » est terminé.',
        postId: postId,
      );
    }
  }

  // --- MENTIONS ---

  Future<List<CommunityProfile>> getMentionableUsers({
    required String currentUserId,
    String query = '',
  }) async {
    final db = await _database.database;
    final trimmed = query.trim().toLowerCase();
    final rows = trimmed.isEmpty
        ? await db.query(
            'community_profiles',
            where: 'user_id != ?',
            whereArgs: [currentUserId],
            orderBy: 'display_name ASC',
            limit: 8,
          )
        : await db.query(
            'community_profiles',
            where:
                'user_id != ? AND (LOWER(username) LIKE ? OR '
                'LOWER(display_name) LIKE ?)',
            whereArgs: [currentUserId, '%$trimmed%', '%$trimmed%'],
            orderBy: 'display_name ASC',
            limit: 8,
          );
    return rows.map(CommunityProfile.fromDatabaseMap).toList();
  }

  Future<CommunityProfile> saveProfile({
    required String userId,
    required String displayName,
    String? avatarPath,
  }) async {
    await _upsertProfile(
      userId: userId,
      displayName: displayName,
      avatarPath: avatarPath,
    );
    final db = await _database.database;
    final rows = await db.query(
      'community_profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return CommunityProfile.fromDatabaseMap(rows.first);
  }

  // --- PRÉFÉRENCES DU MODULE ---

  Future<String> getSetting({
    required String userId,
    required String key,
    String fallback = '',
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'community_settings',
      columns: ['value'],
      where: 'user_id = ? AND key = ?',
      whereArgs: [userId, key],
      limit: 1,
    );
    if (rows.isEmpty) return fallback;
    return rows.first['value'] as String;
  }

  Future<void> setSetting({
    required String userId,
    required String key,
    required String value,
  }) async {
    final db = await _database.database;
    await db.insert(
      'community_settings',
      {'user_id': userId, 'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<CommunityLanguage> getPreferredLanguage(String userId) async {
    final code = await getSetting(
      userId: userId,
      key: 'preferred_language',
      fallback: CommunityLanguage.french.code,
    );
    return CommunityLanguage.fromCode(code);
  }

  Future<void> setPreferredLanguage(
    String userId,
    CommunityLanguage language,
  ) async {
    await setSetting(
      userId: userId,
      key: 'preferred_language',
      value: language.code,
    );
  }

  // --- INTERNES ---

  Future<void> _createPollIfNeeded({
    required String postId,
    String? question,
    List<String>? options,
    DateTime? endsAt,
  }) async {
    final trimmedQuestion = question?.trim() ?? '';
    final cleanedOptions = (options ?? const <String>[])
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList();
    if (trimmedQuestion.isEmpty || cleanedOptions.length < 2) return;

    final db = await _database.database;
    final pollId = _uuid.v4();
    final now = DateTime.now();
    await db.insert('polls', {
      'id': pollId,
      'post_id': postId,
      'question': trimmedQuestion,
      'ends_at': endsAt?.millisecondsSinceEpoch,
      'created_at': now.millisecondsSinceEpoch,
    });
    for (var index = 0; index < cleanedOptions.length; index++) {
      await db.insert('poll_options', {
        'id': _uuid.v4(),
        'poll_id': pollId,
        'label': cleanedOptions[index],
        'position': index,
      });
    }
  }

  Future<List<Post>> _attachPolls(
    List<Post> posts,
    String currentUserId,
  ) async {
    if (posts.isEmpty) return posts;
    final db = await _database.database;
    final postIds = posts.map((post) => post.id).toList();
    final placeholders = List.filled(postIds.length, '?').join(',');
    final pollRows = await db.query(
      'polls',
      where: 'post_id IN ($placeholders)',
      whereArgs: postIds,
    );
    if (pollRows.isEmpty) return posts;

    final pollIds = pollRows.map((row) => row['id'] as String).toList();
    final pollPlaceholders = List.filled(pollIds.length, '?').join(',');
    final optionRows = await db.query(
      'poll_options',
      where: 'poll_id IN ($pollPlaceholders)',
      whereArgs: pollIds,
      orderBy: 'position ASC',
    );
    final voteRows = await db.rawQuery(
      'SELECT option_id, COUNT(*) AS votes FROM poll_votes '
      'WHERE poll_id IN ($pollPlaceholders) GROUP BY option_id',
      pollIds,
    );
    final myVotes = await db.rawQuery(
      'SELECT poll_id, option_id FROM poll_votes '
      'WHERE user_id = ? AND poll_id IN ($pollPlaceholders)',
      [currentUserId, ...pollIds],
    );

    final countsByOption = <String, int>{
      for (final row in voteRows)
        row['option_id'] as String: (row['votes'] as num).toInt(),
    };
    final myOptionByPoll = <String, String>{
      for (final row in myVotes)
        row['poll_id'] as String: row['option_id'] as String,
    };
    final optionsByPoll = <String, List<PollOption>>{};
    for (final row in optionRows) {
      final pollId = row['poll_id'] as String;
      final optionId = row['id'] as String;
      final option = PollOption(
        id: optionId,
        pollId: pollId,
        label: row['label'] as String,
        position: (row['position'] as num?)?.toInt() ?? 0,
        voteCount: countsByOption[optionId] ?? 0,
        votedByMe: myOptionByPoll[pollId] == optionId,
      );
      optionsByPoll.putIfAbsent(pollId, () => []).add(option);
    }

    final pollsByPost = <String, PostPoll>{};
    for (final row in pollRows) {
      final pollId = row['id'] as String;
      final postId = row['post_id'] as String;
      pollsByPost[postId] = PostPoll(
        id: pollId,
        postId: postId,
        question: row['question'] as String,
        endsAt: row['ends_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['ends_at'] as int),
        myOptionId: myOptionByPoll[pollId],
        options: optionsByPoll[pollId] ?? const [],
      );
    }

    return posts
        .map((post) => post.withPoll(pollsByPost[post.id]))
        .toList();
  }

  Future<void> _upsertProfile({
    required String userId,
    required String displayName,
    String? avatarPath,
  }) async {
    final db = await _database.database;
    final existing = await db.query(
      'community_profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.update(
        'community_profiles',
        {
          'display_name': displayName,
          'avatar_path': avatarPath,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return;
    }

    final base = normalizeUsername(displayName);
    var username = base;
    var suffix = 1;
    while (true) {
      final taken = await db.query(
        'community_profiles',
        columns: ['user_id'],
        where: 'username = ?',
        whereArgs: [username],
        limit: 1,
      );
      if (taken.isEmpty) break;
      username = '${base}_${suffix++}';
    }

    await db.insert('community_profiles', {
      'user_id': userId,
      'username': username,
      'display_name': displayName,
      'avatar_path': avatarPath,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _notifyMentions({
    required List<String> mentions,
    required String actorId,
    required String actorName,
    required CommunityNotificationType type,
    required String context,
    String? postId,
    String? commentId,
  }) async {
    if (mentions.isEmpty) return;
    final db = await _database.database;
    final placeholders = List.filled(mentions.length, '?').join(',');
    final rows = await db.query(
      'community_profiles',
      columns: ['user_id', 'username'],
      where: 'username IN ($placeholders)',
      whereArgs: mentions,
    );
    for (final row in rows) {
      final userId = row['user_id'] as String;
      if (userId == actorId) continue;
      await _createNotification(
        userId: userId,
        type: type,
        message: '$actorName vous a mentionné dans $context.',
        postId: postId,
        commentId: commentId,
        actorId: actorId,
        actorName: actorName,
      );
    }
  }

  Future<void> _createNotification({
    required String userId,
    required CommunityNotificationType type,
    required String message,
    String? postId,
    String? commentId,
    String? actorId,
    String? actorName,
  }) async {
    final db = await _database.database;
    await db.insert('community_notifications', {
      'id': _uuid.v4(),
      'user_id': userId,
      'type': type.storageValue,
      'post_id': postId,
      'comment_id': commentId,
      'actor_id': actorId,
      'actor_name': actorName,
      'message': message,
      'is_read': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool> _ownsReportedContent(
    ReportTargetType targetType,
    String targetId,
    String userId,
  ) async {
    final db = await _database.database;
    if (targetType == ReportTargetType.post) {
      final rows = await db.query(
        'posts',
        columns: ['user_id'],
        where: 'id = ?',
        whereArgs: [targetId],
        limit: 1,
      );
      return rows.isNotEmpty && rows.first['user_id'] == userId;
    }
    final rows = await db.rawQuery(
      '''
      SELECT c.user_id AS comment_owner, p.user_id AS post_owner
      FROM comments c JOIN posts p ON p.id = c.post_id
      WHERE c.id = ? LIMIT 1
      ''',
      [targetId],
    );
    if (rows.isEmpty) return false;
    return rows.first['comment_owner'] == userId ||
        rows.first['post_owner'] == userId;
  }

  Future<void> _recordModerationAction({
    required String actorId,
    required String action,
    ReportTargetType? targetType,
    String? targetId,
    String? note,
  }) async {
    final db = await _database.database;
    await db.insert('moderation_actions', {
      'id': _uuid.v4(),
      'actor_id': actorId,
      'target_type': targetType?.storageValue,
      'target_id': targetId,
      'action': action,
      'note': note?.trim() ?? '',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
