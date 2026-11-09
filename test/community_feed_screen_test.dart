import 'dart:typed_data';

import 'package:fittrack_ai/community/data/community_repository.dart';
import 'package:fittrack_ai/community/models/comment_insights.dart';
import 'package:fittrack_ai/community/models/community_notification.dart';
import 'package:fittrack_ai/community/models/community_profile.dart';
import 'package:fittrack_ai/community/models/community_reaction.dart';
import 'package:fittrack_ai/community/models/community_report.dart';
import 'package:fittrack_ai/community/models/post.dart';
import 'package:fittrack_ai/community/models/post_comment.dart';
import 'package:fittrack_ai/community/screens/community_feed_screen.dart';
import 'package:fittrack_ai/models/user.dart';
import 'package:fittrack_ai/theme/fit_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dépôt en mémoire pour les tests d'interface.
///
/// Les tests de widgets tournent dans une zone « fake async » : une vraie
/// base SQLite (isolate séparé) n'y répond jamais, ce qui bloquerait
/// `pumpAndSettle`. La persistance SQLite est couverte séparément par
/// `community_repository_test.dart`.
class _FakeCommunityRepository extends CommunityRepository {
  final List<Post> posts = [];
  final Map<String, List<PostComment>> comments = {};
  final Set<String> liked = {};
  final Map<String, CommunityReaction> reactions = {};
  final Set<String> bookmarks = {};
  int _sequence = 0;

  @override
  Future<List<Post>> getFeed({
    required String currentUserId,
    PostTheme? theme,
  }) async {
    final items =
        posts
            .where((post) => theme == null || post.theme == theme)
            .map(
              (post) => post.copyWith(
                commentCount: comments[post.id]?.length ?? 0,
                likedByMe: liked.contains(post.id),
                myReaction: reactions[post.id],
                bookmarkedByMe: bookmarks.contains(post.id),
              ),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<List<Post>> getDrafts({required String userId}) async {
    return posts
        .where((post) => post.isDraft && post.userId == userId)
        .toList();
  }

  @override
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
    final now = DateTime.now().add(Duration(milliseconds: _sequence++));
    final post = Post(
      id: 'post-${posts.length + 1}',
      userId: userId,
      authorName: authorName,
      authorAvatarPath: authorAvatarPath,
      content: content.trim(),
      imageBytes: imageBytes,
      videoBytes: videoBytes,
      videoName: videoName,
      theme: theme,
      createdAt: now,
      updatedAt: now,
      isDraft: isDraft,
      allowAnonymousComments: allowAnonymousComments,
    );
    posts.add(post);
    return post;
  }

  @override
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
    final index = posts.indexWhere((post) => post.id == postId);
    final current = posts[index];
    posts[index] = current.copyWith(
      content: content.trim(),
      theme: theme,
      isDraft: isDraft,
      allowAnonymousComments: allowAnonymousComments,
      imageBytes: imageBytes,
      videoBytes: videoBytes,
      videoName: videoName,
      updatedAt: DateTime.now(),
    );
    return posts[index];
  }

  @override
  Future<void> publishDraft({
    required String postId,
    required String userId,
  }) async {
    final index = posts.indexWhere((post) => post.id == postId);
    posts[index] = posts[index].copyWith(isDraft: false);
  }

  @override
  Future<void> deletePost({
    required String postId,
    required String userId,
  }) async {
    posts.removeWhere((post) => post.id == postId);
    comments.remove(postId);
  }

  @override
  Future<bool> togglePinPost({
    required String postId,
    required String userId,
  }) async {
    final index = posts.indexWhere((post) => post.id == postId);
    final next = !posts[index].isPinned;
    posts[index] = posts[index].copyWith(isPinned: next);
    return next;
  }

  @override
  Future<void> registerShare({
    required String postId,
    required String userId,
  }) async {}

  @override
  Future<CommunityReaction?> toggleReaction({
    required String postId,
    required String userId,
    required CommunityReaction reaction,
    String? actorName,
  }) async {
    final index = posts.indexWhere((post) => post.id == postId);
    if (index < 0) return null;
    final current = posts[index];
    final previous = reactions[postId];
    final counts = Map<CommunityReaction, int>.from(current.reactionCounts);
    if (previous != null) {
      counts[previous] = (counts[previous] ?? 1) - 1;
      if (counts[previous]! <= 0) counts.remove(previous);
    }
    if (previous == reaction) {
      reactions.remove(postId);
      liked.remove(postId);
      posts[index] = current.copyWith(
        clearMyReaction: true,
        reactionCounts: counts,
        likeCount: counts.values.fold<int>(0, (sum, count) => sum + count),
        likedByMe: false,
      );
      return null;
    }
    reactions[postId] = reaction;
    if (reaction == CommunityReaction.like) liked.add(postId);
    counts[reaction] = (counts[reaction] ?? 0) + 1;
    posts[index] = current.copyWith(
      myReaction: reaction,
      reactionCounts: counts,
      likeCount: counts.values.fold<int>(0, (sum, count) => sum + count),
      likedByMe: reaction == CommunityReaction.like,
    );
    return reaction;
  }

  @override
  Future<List<ReactionEntry>> getReactions(String postId) async {
    final reaction = reactions[postId];
    if (reaction == null) return [];
    return [
      ReactionEntry(
        userId: 'user-1',
        userName: 'Afnen Ben Yakhlef',
        reaction: reaction,
      ),
    ];
  }

  @override
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

  @override
  Future<List<PostComment>> getComments(
    String postId, {
    String currentUserId = '',
  }) async {
    return [...?comments[postId]];
  }

  @override
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
    final now = DateTime.now();
    final comment = PostComment(
      id: 'comment-${_sequence++}',
      postId: postId,
      userId: userId,
      authorName: authorName,
      authorAvatarPath: authorAvatarPath,
      content: content.trim(),
      createdAt: now,
      updatedAt: now,
      parentId: parentId,
      isAnonymous: isAnonymous,
      sentiment: sentiment,
      isFlagged: isFlagged,
      flagReason: flagReason,
      isSpam: isSpam,
      spamReason: spamReason,
    );
    comments.putIfAbsent(postId, () => []).add(comment);
    return comment;
  }

  @override
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
    for (final entry in comments.entries) {
      final index = entry.value.indexWhere((item) => item.id == commentId);
      if (index < 0) continue;
      final updated = entry.value[index].copyWith(
        content: content.trim(),
        sentiment: sentiment,
        updatedAt: DateTime.now(),
      );
      entry.value[index] = updated;
      return updated;
    }
    throw const CommunityException('Commentaire introuvable.');
  }

  @override
  Future<void> deleteComment({
    required String commentId,
    required String userId,
  }) async {
    for (final entry in comments.entries) {
      entry.value.removeWhere((item) => item.id == commentId);
    }
  }

  @override
  Future<bool> togglePinComment({
    required String commentId,
    required String postId,
    required String userId,
  }) async {
    final list = comments[postId] ?? [];
    final index = list.indexWhere((item) => item.id == commentId);
    if (index < 0) return false;
    final next = !list[index].isPinned;
    list[index] = list[index].copyWith(isPinned: next);
    return next;
  }

  @override
  Future<bool> toggleBestAnswer({
    required String commentId,
    required String postId,
    required String userId,
  }) async {
    final list = comments[postId] ?? [];
    final index = list.indexWhere((item) => item.id == commentId);
    if (index < 0) return false;
    final next = !list[index].isBestAnswer;
    for (var i = 0; i < list.length; i++) {
      list[i] = list[i].copyWith(isBestAnswer: false);
    }
    if (next) list[index] = list[index].copyWith(isBestAnswer: true);
    return next;
  }

  @override
  Future<CommunityReaction?> toggleCommentReaction({
    required String commentId,
    required String userId,
    required CommunityReaction reaction,
    String? actorName,
  }) async {
    for (final list in comments.values) {
      final index = list.indexWhere((item) => item.id == commentId);
      if (index < 0) continue;
      final current = list[index];
      if (current.myReaction == reaction) {
        list[index] = current.copyWith(clearMyReaction: true, reactionCount: 0);
        return null;
      }
      list[index] = current.copyWith(
        myReaction: reaction,
        reactionCount: 1,
      );
      return reaction;
    }
    return null;
  }

  @override
  Future<List<ReactionEntry>> getCommentReactions(String commentId) async {
    return [];
  }

  @override
  Future<void> votePoll({
    required String postId,
    required String optionId,
    required String userId,
    String? actorName,
  }) async {}

  @override
  Future<bool> toggleBookmark({
    required String postId,
    required String userId,
    String? collectionId,
  }) async {
    if (bookmarks.contains(postId)) {
      bookmarks.remove(postId);
      return false;
    }
    bookmarks.add(postId);
    return true;
  }

  @override
  Future<List<Post>> getBookmarkedPosts({
    required String currentUserId,
    String? collectionId,
  }) async {
    return posts.where((post) => bookmarks.contains(post.id)).toList();
  }

  @override
  Future<List<BookmarkCollection>> getCollections(String userId) async => [];

  @override
  Future<BookmarkCollection> createCollection({
    required String userId,
    required String name,
  }) async {
    return BookmarkCollection(
      id: 'collection-${_sequence++}',
      userId: userId,
      name: name,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteCollection({
    required String collectionId,
    required String userId,
  }) async {}

  @override
  Future<void> reportContent({
    required ReportTargetType targetType,
    required String targetId,
    required String reporterId,
    String? reporterName,
    required ReportReason reason,
    String? details,
  }) async {}

  @override
  Future<List<ContentReport>> getMyReports(String userId) async => [];

  @override
  Future<List<ContentReport>> getReportsOnMyContent(String userId) async => [];

  @override
  Future<void> resolveReport({
    required String reportId,
    required String userId,
    required ReportStatus status,
    String? note,
  }) async {}

  @override
  Future<List<ContentFlag>> getFlagsForMyContent(String userId) async => [];

  @override
  Future<ContentFlag> saveContentFlag({
    required ReportTargetType targetType,
    required String targetId,
    required String ownerId,
    String? postOwnerId,
    required String category,
    required String explanation,
    required AiSource source,
  }) async {
    return ContentFlag(
      id: 'flag-${_sequence++}',
      targetType: targetType,
      targetId: targetId,
      ownerId: ownerId,
      category: category,
      explanation: explanation,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> dismissFlag({
    required String flagId,
    required String userId,
  }) async {}

  @override
  Future<List<ModerationAction>> getModerationHistory(String userId) async =>
      [];

  @override
  Future<List<CommunityNotification>> getNotifications(String userId) async =>
      [];

  @override
  Future<int> getUnreadNotificationCount(String userId) async => 0;

  @override
  Future<void> markNotificationRead(String notificationId) async {}

  @override
  Future<void> markAllNotificationsRead(String userId) async {}

  @override
  Future<void> checkPollClosures(String userId) async {}

  @override
  Future<List<CommunityProfile>> getMentionableUsers({
    required String currentUserId,
    String query = '',
  }) async => [];
}

void main() {
  late _FakeCommunityRepository repository;

  setUp(() {
    repository = _FakeCommunityRepository();
  });

  final user = User(
    id: 'user-1',
    firstName: 'Afnen',
    lastName: 'Ben Yakhlef',
    email: 'afnen@example.com',
    passwordHash: 'x',
    isOnboarded: true,
    createdAt: DateTime(2026),
  );

  Future<void> pumpFeed(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FitTheme.dark,
        home: Scaffold(
          body: CommunityFeedScreen(user: user, repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('le fil affiche les publications et filtre par thème', (
    tester,
  ) async {
    await repository.createPost(
      userId: user.id,
      authorName: 'Afnen Ben Yakhlef',
      content: 'Repas équilibré',
      theme: PostTheme.meal,
    );
    await repository.createPost(
      userId: user.id,
      authorName: 'Afnen Ben Yakhlef',
      content: 'Séance cardio',
      theme: PostTheme.sport,
    );

    await pumpFeed(tester);

    expect(find.text('Publications'), findsOneWidget);
    expect(find.text('Repas équilibré'), findsOneWidget);
    expect(find.text('Séance cardio'), findsOneWidget);
    expect(find.text('2 publications'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Sport'));
    await tester.pumpAndSettle();

    expect(find.text('Séance cardio'), findsOneWidget);
    expect(find.text('Repas équilibré'), findsNothing);
    expect(find.text('1 publication'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recherche une publication par mot-clé ou hashtag', (
    tester,
  ) async {
    await repository.createPost(
      userId: user.id,
      authorName: 'Afnen Ben Yakhlef',
      content: 'Déjeuner #protéines',
      theme: PostTheme.meal,
    );
    await repository.createPost(
      userId: user.id,
      authorName: 'Afnen Ben Yakhlef',
      content: 'Séance de course',
      theme: PostTheme.sport,
    );
    await pumpFeed(tester);

    await tester.tap(find.byTooltip('Rechercher des publications'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '#protéines');
    await tester.tap(find.widgetWithText(FilledButton, 'Rechercher'));
    await tester.pumpAndSettle();

    expect(find.text('Déjeuner #protéines'), findsOneWidget);
    expect(find.text('Séance de course'), findsNothing);
    expect(find.text('1 publication'), findsOneWidget);
  });

  testWidgets('trie le fil du plus ancien au plus récent', (tester) async {
    await repository.createPost(
      userId: user.id,
      authorName: 'Afnen Ben Yakhlef',
      content: 'Publication ancienne',
      theme: PostTheme.meal,
    );
    await repository.createPost(
      userId: user.id,
      authorName: 'Afnen Ben Yakhlef',
      content: 'Publication récente',
      theme: PostTheme.sport,
    );
    await pumpFeed(tester);

    await tester.tap(find.byTooltip('Trier les publications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plus anciennes'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Publication ancienne')).dy,
      lessThan(tester.getTopLeft(find.text('Publication récente')).dy),
    );
  });

  testWidgets('PUB01 : publier depuis le fil ajoute la publication', (
    tester,
  ) async {
    await pumpFeed(tester);

    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle publication'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'Petit-déjeuner protéiné avant la séance',
    );
    await tester.pumpAndSettle();

    final publishButton = find.text('Publier').last;
    await tester.ensureVisible(publishButton);
    await tester.pumpAndSettle();
    await tester.tap(publishButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Petit-déjeuner protéiné avant la séance'),
      findsOneWidget,
    );
    expect(find.text('1 publication'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PUB04 : ajouter un commentaire depuis le fil', (tester) async {
    await repository.createPost(
      userId: user.id,
      authorName: 'Afnen Ben Yakhlef',
      content: 'Publication à commenter',
      theme: PostTheme.nutrition,
    );
    await pumpFeed(tester);

    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Commentaires'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Très bonne idée !');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Très bonne idée !'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
