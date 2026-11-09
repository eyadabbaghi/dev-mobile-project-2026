import 'package:fittrack_ai/community/data/community_database.dart';
import 'package:fittrack_ai/community/data/community_repository.dart';
import 'package:fittrack_ai/community/models/comment_insights.dart';
import 'package:fittrack_ai/community/models/community_notification.dart';
import 'package:fittrack_ai/community/models/community_reaction.dart';
import 'package:fittrack_ai/community/models/community_report.dart';
import 'package:fittrack_ai/community/models/post.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late CommunityRepository repository;

  setUp(() async {
    CommunityDatabase.pathOverride = ':memory:';
    await CommunityDatabase.instance.close();
    repository = CommunityRepository();
  });

  tearDown(() async {
    await CommunityDatabase.instance.close();
    CommunityDatabase.pathOverride = null;
  });

  test('PUB01 : crée une publication et la retrouve dans le fil', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen Ben Yakhlef',
      content: '  Salade protéinée maison  ',
      theme: PostTheme.meal,
    );

    expect(post.content, 'Salade protéinée maison');

    final feed = await repository.getFeed(currentUserId: 'user-1');
    expect(feed, hasLength(1));
    expect(feed.first.id, post.id);
    expect(feed.first.authorName, 'Afnen Ben Yakhlef');
    expect(feed.first.theme, PostTheme.meal);
    expect(feed.first.likeCount, 0);
    expect(feed.first.commentCount, 0);
    expect(feed.first.likedByMe, isFalse);
  });

  test('PUB01 : refuse une publication vide', () async {
    await expectLater(
      repository.createPost(
        userId: 'user-1',
        authorName: 'Afnen',
        content: '   ',
        theme: PostTheme.sport,
      ),
      throwsA(isA<CommunityException>()),
    );
  });

  test('PUB02 : le fil est trié du plus récent au plus ancien', () async {
    final first = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Première publication',
      theme: PostTheme.meal,
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Deuxième publication',
      theme: PostTheme.sport,
    );

    final feed = await repository.getFeed(currentUserId: 'user-1');
    expect(feed.map((post) => post.id).toList(), [second.id, first.id]);
  });

  test('PUB03 / RG08 : seul le propriétaire peut modifier sa publication', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Texte initial',
      theme: PostTheme.nutrition,
    );

    final updated = await repository.updatePost(
      postId: post.id,
      userId: 'user-1',
      content: 'Texte corrigé',
      theme: PostTheme.progress,
    );
    expect(updated.content, 'Texte corrigé');
    expect(updated.theme, PostTheme.progress);

    await expectLater(
      repository.updatePost(
        postId: post.id,
        userId: 'user-2',
        content: 'Tentative de modification',
        theme: PostTheme.meal,
      ),
      throwsA(isA<CommunityException>()),
    );
  });

  test('PUB03 / RG08 : seul le propriétaire peut supprimer sa publication', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'À supprimer',
      theme: PostTheme.sport,
    );

    await expectLater(
      repository.deletePost(postId: post.id, userId: 'user-2'),
      throwsA(isA<CommunityException>()),
    );
    expect(await repository.getFeed(currentUserId: 'user-1'), hasLength(1));

    await repository.deletePost(postId: post.id, userId: 'user-1');
    expect(await repository.getFeed(currentUserId: 'user-1'), isEmpty);
  });

  test('PUB04 / RG08 : ajout, lecture, modification et suppression de ses commentaires', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Une publication',
      theme: PostTheme.meal,
    );

    final comment = await repository.addComment(
      postId: post.id,
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Mon premier commentaire',
    );
    expect(await repository.getComments(post.id), hasLength(1));

    final updated = await repository.updateComment(
      commentId: comment.id,
      userId: 'user-1',
      content: 'Commentaire corrigé',
    );
    expect(updated.content, 'Commentaire corrigé');

    await expectLater(
      repository.updateComment(
        commentId: comment.id,
        userId: 'user-2',
        content: 'Modification interdite',
      ),
      throwsA(isA<CommunityException>()),
    );
    await expectLater(
      repository.deleteComment(commentId: comment.id, userId: 'user-2'),
      throwsA(isA<CommunityException>()),
    );

    await repository.deleteComment(
      commentId: comment.id,
      userId: 'user-1',
    );
    expect(await repository.getComments(post.id), isEmpty);
  });

  test('PUB02 : le nombre de commentaires remonte dans le fil', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Publication commentée',
      theme: PostTheme.meal,
    );
    await repository.addComment(
      postId: post.id,
      userId: 'user-2',
      authorName: 'Sami',
      content: 'Super !',
    );

    final feed = await repository.getFeed(currentUserId: 'user-1');
    expect(feed.first.commentCount, 1);
    expect(feed.first.interactionCount, 1);
  });

  test('PUB05 : filtre thématique du fil', () async {
    await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Repas du jour',
      theme: PostTheme.meal,
    );
    await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Séance de sport',
      theme: PostTheme.sport,
    );

    final sportFeed = await repository.getFeed(
      currentUserId: 'user-1',
      theme: PostTheme.sport,
    );
    expect(sportFeed, hasLength(1));
    expect(sportFeed.first.content, 'Séance de sport');
  });

  test('PUB02 : le j\'aime met à jour les compteurs', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Publication à liker',
      theme: PostTheme.progress,
    );

    final liked = await repository.toggleLike(
      postId: post.id,
      userId: 'user-2',
    );
    expect(liked, isTrue);

    var feed = await repository.getFeed(currentUserId: 'user-2');
    expect(feed.first.likeCount, 1);
    expect(feed.first.likedByMe, isTrue);

    final unliked = await repository.toggleLike(
      postId: post.id,
      userId: 'user-2',
    );
    expect(unliked, isFalse);

    feed = await repository.getFeed(currentUserId: 'user-2');
    expect(feed.first.likeCount, 0);
    expect(feed.first.likedByMe, isFalse);
  });

  test('RG08 : la suppression d\'une publication supprime ses commentaires', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Publication avec commentaire',
      theme: PostTheme.nutrition,
    );
    await repository.addComment(
      postId: post.id,
      userId: 'user-2',
      authorName: 'Sami',
      content: 'Commentaire',
    );

    await repository.deletePost(postId: post.id, userId: 'user-1');
    expect(await repository.getComments(post.id), isEmpty);
  });

  test('Brouillons : création, visibilité privée et publication', () async {
    final draft = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Brouillon en cours',
      theme: PostTheme.meal,
      isDraft: true,
    );
    expect(draft.isDraft, isTrue);

    expect(await repository.getFeed(currentUserId: 'user-1'), isEmpty);
    final drafts = await repository.getDrafts(userId: 'user-1');
    expect(drafts, hasLength(1));
    expect(drafts.first.id, draft.id);
    expect(await repository.getDrafts(userId: 'user-2'), isEmpty);

    await expectLater(
      repository.publishDraft(postId: draft.id, userId: 'user-2'),
      throwsA(isA<CommunityException>()),
    );

    await repository.publishDraft(postId: draft.id, userId: 'user-1');
    expect(await repository.getDrafts(userId: 'user-1'), isEmpty);
    expect(await repository.getFeed(currentUserId: 'user-1'), hasLength(1));
  });

  test('Épinglage : le propriétaire épingle et le fil remonte la publication', () async {
    final older = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Ancienne publication',
      theme: PostTheme.meal,
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final newer = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Nouvelle publication',
      theme: PostTheme.sport,
    );

    await expectLater(
      repository.togglePinPost(postId: older.id, userId: 'user-2'),
      throwsA(isA<CommunityException>()),
    );

    final pinned = await repository.togglePinPost(
      postId: older.id,
      userId: 'user-1',
    );
    expect(pinned, isTrue);

    final feed = await repository.getFeed(currentUserId: 'user-1');
    expect(feed.first.id, older.id);
    expect(feed.first.isPinned, isTrue);
    expect(feed[1].id, newer.id);

    final unpinned = await repository.togglePinPost(
      postId: older.id,
      userId: 'user-1',
    );
    expect(unpinned, isFalse);
  });

  test('Réactions : six réactions, compteurs, changement et retrait', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Publication à réagir',
      theme: PostTheme.progress,
    );

    expect(
      await repository.toggleReaction(
        postId: post.id,
        userId: 'user-2',
        reaction: CommunityReaction.love,
        actorName: 'Sami',
      ),
      CommunityReaction.love,
    );
    var fetched = await repository.getPost(post.id, 'user-2');
    expect(fetched!.reactionCountOf(CommunityReaction.love), 1);
    expect(fetched.myReaction, CommunityReaction.love);
    expect(fetched.likeCount, 1);

    expect(
      await repository.toggleReaction(
        postId: post.id,
        userId: 'user-3',
        reaction: CommunityReaction.wow,
      ),
      CommunityReaction.wow,
    );
    fetched = await repository.getPost(post.id, 'user-2');
    expect(fetched!.reactionCountOf(CommunityReaction.love), 1);
    expect(fetched.reactionCountOf(CommunityReaction.wow), 1);
    expect(fetched.likeCount, 2);

    // Changer de réaction remplace la précédente sans doublon.
    await repository.toggleReaction(
      postId: post.id,
      userId: 'user-2',
      reaction: CommunityReaction.haha,
    );
    fetched = await repository.getPost(post.id, 'user-2');
    expect(fetched!.myReaction, CommunityReaction.haha);
    expect(fetched.reactionCountOf(CommunityReaction.love), 0);
    expect(fetched.reactionCountOf(CommunityReaction.haha), 1);

    final entries = await repository.getReactions(post.id);
    expect(entries, hasLength(2));
    expect(
      entries.where((entry) => entry.userId == 'user-2').first.reaction,
      CommunityReaction.haha,
    );

    // Ré-appuyer sur la même réaction la retire.
    expect(
      await repository.toggleReaction(
        postId: post.id,
        userId: 'user-2',
        reaction: CommunityReaction.haha,
      ),
      isNull,
    );
    fetched = await repository.getPost(post.id, 'user-2');
    expect(fetched!.myReaction, isNull);
    expect(fetched.reactionCountOf(CommunityReaction.haha), 0);
  });

  test('Commentaires imbriqués : réponses rattachées au bon parent', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Question sur la nutrition',
      theme: PostTheme.nutrition,
    );
    final parent = await repository.addComment(
      postId: post.id,
      userId: 'user-2',
      authorName: 'Sami',
      content: 'Quelle quantité de protéines ?',
    );
    final reply = await repository.addComment(
      postId: post.id,
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Environ 1,6 g par kilo.',
      parentId: parent.id,
    );
    expect(reply.parentId, parent.id);

    final comments = await repository.getComments(
      post.id,
      currentUserId: 'user-1',
    );
    expect(comments, hasLength(2));
    expect(
      comments.where((comment) => comment.parentId == parent.id),
      hasLength(1),
    );

    final otherPost = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Autre publication',
      theme: PostTheme.sport,
    );
    await expectLater(
      repository.addComment(
        postId: otherPost.id,
        userId: 'user-1',
        authorName: 'Afnen',
        content: 'Réponse invalide',
        parentId: parent.id,
      ),
      throwsA(isA<CommunityException>()),
    );
  });

  test('Réactions de commentaire : ajout, compteur et retrait', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Publication',
      theme: PostTheme.meal,
    );
    final comment = await repository.addComment(
      postId: post.id,
      userId: 'user-2',
      authorName: 'Sami',
      content: 'Commentaire réagissable',
    );

    await repository.toggleCommentReaction(
      commentId: comment.id,
      userId: 'user-1',
      reaction: CommunityReaction.like,
      actorName: 'Afnen',
    );
    var comments = await repository.getComments(
      post.id,
      currentUserId: 'user-1',
    );
    expect(comments.first.reactionCount, 1);
    expect(comments.first.myReaction, CommunityReaction.like);

    final entries = await repository.getCommentReactions(comment.id);
    expect(entries, hasLength(1));

    await repository.toggleCommentReaction(
      commentId: comment.id,
      userId: 'user-1',
      reaction: CommunityReaction.like,
    );
    comments = await repository.getComments(
      post.id,
      currentUserId: 'user-1',
    );
    expect(comments.first.reactionCount, 0);
    expect(comments.first.myReaction, isNull);
  });

  test('Commentaires : épinglage et meilleure réponse réservés au propriétaire', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Publication avec commentaires',
      theme: PostTheme.sport,
    );
    final first = await repository.addComment(
      postId: post.id,
      userId: 'user-2',
      authorName: 'Sami',
      content: 'Premier commentaire',
    );
    final second = await repository.addComment(
      postId: post.id,
      userId: 'user-3',
      authorName: 'Nina',
      content: 'Deuxième commentaire',
    );

    await expectLater(
      repository.togglePinComment(
        commentId: first.id,
        postId: post.id,
        userId: 'user-2',
      ),
      throwsA(isA<CommunityException>()),
    );

    expect(
      await repository.togglePinComment(
        commentId: first.id,
        postId: post.id,
        userId: 'user-1',
      ),
      isTrue,
    );

    expect(
      await repository.toggleBestAnswer(
        commentId: second.id,
        postId: post.id,
        userId: 'user-1',
      ),
      isTrue,
    );

    final comments = await repository.getComments(
      post.id,
      currentUserId: 'user-1',
    );
    expect(comments.firstWhere((c) => c.id == first.id).isPinned, isTrue);
    expect(
      comments.firstWhere((c) => c.id == second.id).isBestAnswer,
      isTrue,
    );

    // Une seule meilleure réponse à la fois.
    await repository.toggleBestAnswer(
      commentId: first.id,
      postId: post.id,
      userId: 'user-1',
    );
    final updated = await repository.getComments(
      post.id,
      currentUserId: 'user-1',
    );
    expect(updated.firstWhere((c) => c.id == first.id).isBestAnswer, isTrue);
    expect(updated.firstWhere((c) => c.id == second.id).isBestAnswer, isFalse);
  });

  test('Sondages : options, vote unique par membre et clôture', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Quel est votre repas préféré ?',
      theme: PostTheme.meal,
      pollQuestion: 'Repas préféré',
      pollOptions: const ['Petit-déjeuner', 'Déjeuner', 'Dîner'],
    );
    var fetched = await repository.getPost(post.id, 'user-2');
    expect(fetched!.poll, isNotNull);
    expect(fetched.poll!.question, 'Repas préféré');
    expect(fetched.poll!.options, hasLength(3));

    final option = fetched.poll!.options.first;
    await repository.votePoll(
      postId: post.id,
      optionId: option.id,
      userId: 'user-2',
      actorName: 'Sami',
    );
    fetched = await repository.getPost(post.id, 'user-2');
    expect(fetched!.poll!.myOptionId, option.id);
    expect(fetched.poll!.totalVotes, 1);

    // Revoter remplace le vote au lieu d'en ajouter un second.
    await repository.votePoll(
      postId: post.id,
      optionId: fetched.poll!.options[1].id,
      userId: 'user-2',
    );
    fetched = await repository.getPost(post.id, 'user-2');
    expect(fetched!.poll!.totalVotes, 1);
    expect(fetched.poll!.myOptionId, fetched.poll!.options[1].id);

    final closed = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Sondage terminé',
      theme: PostTheme.meal,
      pollQuestion: 'Déjà fini ?',
      pollOptions: const ['Oui', 'Non'],
      pollEndsAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    final closedFetched = await repository.getPost(closed.id, 'user-1');
    await expectLater(
      repository.votePoll(
        postId: closed.id,
        optionId: closedFetched!.poll!.options.first.id,
        userId: 'user-1',
      ),
      throwsA(isA<CommunityException>()),
    );

    await repository.checkPollClosures('user-1');
    final notifications = await repository.getNotifications('user-1');
    expect(
      notifications.any(
        (notification) =>
            notification.type == CommunityNotificationType.pollClosed,
      ),
      isTrue,
    );
  });

  test('Enregistrements : favoris, collections et filtre', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'À enregistrer',
      theme: PostTheme.progress,
    );
    final collection = await repository.createCollection(
      userId: 'user-2',
      name: 'Recettes',
    );

    expect(
      await repository.toggleBookmark(
        postId: post.id,
        userId: 'user-2',
        collectionId: collection.id,
      ),
      isTrue,
    );

    final collections = await repository.getCollections('user-2');
    expect(collections, hasLength(1));
    expect(collections.first.name, 'Recettes');
    expect(collections.first.itemCount, 1);

    final saved = await repository.getBookmarkedPosts(
      currentUserId: 'user-2',
    );
    expect(saved, hasLength(1));
    expect(saved.first.id, post.id);
    expect(saved.first.bookmarkedByMe, isTrue);

    final filtered = await repository.getBookmarkedPosts(
      currentUserId: 'user-2',
      collectionId: collection.id,
    );
    expect(filtered, hasLength(1));

    final otherCollection = await repository.createCollection(
      userId: 'user-2',
      name: 'Sport',
    );
    final empty = await repository.getBookmarkedPosts(
      currentUserId: 'user-2',
      collectionId: otherCollection.id,
    );
    expect(empty, isEmpty);

    expect(
      await repository.toggleBookmark(postId: post.id, userId: 'user-2'),
      isFalse,
    );
    expect(
      await repository.getBookmarkedPosts(currentUserId: 'user-2'),
      isEmpty,
    );

    await repository.deleteCollection(
      collectionId: otherCollection.id,
      userId: 'user-2',
    );
    expect(await repository.getCollections('user-2'), hasLength(1));
    await expectLater(
      repository.deleteCollection(
        collectionId: collection.id,
        userId: 'user-3',
      ),
      throwsA(isA<CommunityException>()),
    );
  });

  test('Partage : le compteur de partages est incrémenté', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Publication partagée',
      theme: PostTheme.sport,
    );
    await repository.registerShare(postId: post.id, userId: 'user-2');
    await repository.registerShare(postId: post.id, userId: 'user-3');

    final fetched = await repository.getPost(post.id, 'user-1');
    expect(fetched!.shareCount, 2);
    expect(fetched.interactionCount, 2);
  });

  test('Signalements : dépôt, liste, résolution propriétaire et historique', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Publication signalée',
      theme: PostTheme.nutrition,
    );
    await repository.reportContent(
      targetType: ReportTargetType.post,
      targetId: post.id,
      reporterId: 'user-2',
      reporterName: 'Sami',
      reason: ReportReason.spam,
      details: 'Contenu promotionnel',
    );

    final mine = await repository.getMyReports('user-2');
    expect(mine, hasLength(1));
    expect(mine.first.reason, ReportReason.spam);
    expect(mine.first.status, ReportStatus.pending);
    expect(mine.first.targetPreview, contains('Publication signalée'));

    final received = await repository.getReportsOnMyContent('user-1');
    expect(received, hasLength(1));
    expect(received.first.reporterName, 'Sami');

    // Un membre qui n'est pas propriétaire du contenu ne peut pas résoudre.
    await expectLater(
      repository.resolveReport(
        reportId: received.first.id,
        userId: 'user-2',
        status: ReportStatus.reviewed,
      ),
      throwsA(isA<CommunityException>()),
    );

    await repository.resolveReport(
      reportId: received.first.id,
      userId: 'user-1',
      status: ReportStatus.reviewed,
      note: 'Traité',
    );
    final resolved = await repository.getReportsOnMyContent('user-1');
    expect(resolved.first.status, ReportStatus.reviewed);
    expect(resolved.first.resolutionNote, 'Traité');

    final history = await repository.getModerationHistory('user-1');
    expect(history, isNotEmpty);
    expect(
      history.any((action) => action.action.contains('examiné')),
      isTrue,
    );
  });

  test('Alertes IA : dépôt, consultation et rejet par le propriétaire', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Publication à vérifier',
      theme: PostTheme.meal,
    );
    final flag = await repository.saveContentFlag(
      targetType: ReportTargetType.post,
      targetId: post.id,
      ownerId: 'user-1',
      category: 'Contenu sensible',
      explanation: 'Ton agressif détecté',
      source: AiSource.local,
    );

    final flags = await repository.getFlagsForMyContent('user-1');
    expect(flags, hasLength(1));
    expect(flags.first.category, 'Contenu sensible');
    expect(flags.first.status, ContentFlagStatus.pending);

    await expectLater(
      repository.dismissFlag(flagId: flag.id, userId: 'user-2'),
      throwsA(isA<CommunityException>()),
    );

    await repository.dismissFlag(flagId: flag.id, userId: 'user-1');
    final dismissed = await repository.getFlagsForMyContent('user-1');
    expect(dismissed.first.status, ContentFlagStatus.dismissed);

    final history = await repository.getModerationHistory('user-1');
    expect(
      history.any((action) => action.action.contains('alerte IA')),
      isTrue,
    );
  });

  test('Notifications : réactions et commentaires, lecture ciblée et globale', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Publication suivie',
      theme: PostTheme.progress,
    );

    await repository.toggleReaction(
      postId: post.id,
      userId: 'user-2',
      reaction: CommunityReaction.love,
      actorName: 'Sami',
    );
    await repository.addComment(
      postId: post.id,
      userId: 'user-3',
      authorName: 'Nina',
      content: 'Bravo !',
    );

    expect(await repository.getUnreadNotificationCount('user-1'), 2);
    final notifications = await repository.getNotifications('user-1');
    expect(notifications, hasLength(2));
    expect(
      notifications.any(
        (item) => item.type == CommunityNotificationType.reaction,
      ),
      isTrue,
    );
    expect(
      notifications.any(
        (item) => item.type == CommunityNotificationType.comment,
      ),
      isTrue,
    );

    await repository.markNotificationRead(notifications.first.id);
    expect(await repository.getUnreadNotificationCount('user-1'), 1);

    await repository.markAllNotificationsRead('user-1');
    expect(await repository.getUnreadNotificationCount('user-1'), 0);
  });

  test('Mentions : profils, notifications et suggestion de membres', () async {
    await repository.saveProfile(userId: 'user-2', displayName: 'Sami');
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Merci @sami pour ton aide',
      theme: PostTheme.nutrition,
    );

    expect(post.mentions, contains('sami'));
    final notified = await repository.getNotifications('user-2');
    expect(
      notified.any(
        (item) =>
            item.type == CommunityNotificationType.mention &&
            item.postId == post.id,
      ),
      isTrue,
    );

    final mentionable = await repository.getMentionableUsers(
      currentUserId: 'user-1',
    );
    expect(mentionable.map((profile) => profile.username), contains('sami'));
    expect(
      mentionable.any((profile) => profile.userId == 'user-1'),
      isFalse,
    );

    final search = await repository.getMentionableUsers(
      currentUserId: 'user-1',
      query: 'sam',
    );
    expect(search, hasLength(1));
  });

  test('Hashtags : extraction et persistance dans le fil', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Séance sportive #sport #progress',
      theme: PostTheme.sport,
    );
    expect(post.hashtags, containsAll(['sport', 'progress']));

    final feed = await repository.getFeed(currentUserId: 'user-1');
    expect(feed.first.hashtags, contains('sport'));
  });

  test('Commentaires anonymes : identité masquée mais auteur conservé', () async {
    final post = await repository.createPost(
      userId: 'user-1',
      authorName: 'Afnen',
      content: 'Publication ouverte aux anonymes',
      theme: PostTheme.meal,
      allowAnonymousComments: true,
    );
    final comment = await repository.addComment(
      postId: post.id,
      userId: 'user-2',
      authorName: 'Sami',
      content: 'Je préfère rester discret',
      isAnonymous: true,
      sentiment: CommentSentiment.neutral,
    );
    expect(comment.isAnonymous, isTrue);
    expect(comment.displayAuthorName, 'Anonyme');
    expect(comment.userId, 'user-2');

    final fetched = await repository.getPost(post.id, 'user-1');
    expect(fetched!.allowAnonymousComments, isTrue);
  });

  test('Préférences du module : réglages et langue préférée', () async {
    expect(
      await repository.getSetting(
        userId: 'user-1',
        key: 'absent',
        fallback: 'défaut',
      ),
      'défaut',
    );

    await repository.setSetting(
      userId: 'user-1',
      key: 'theme',
      value: 'sombre',
    );
    expect(
      await repository.getSetting(userId: 'user-1', key: 'theme'),
      'sombre',
    );

    expect(
      await repository.getPreferredLanguage('user-1'),
      CommunityLanguage.french,
    );
    await repository.setPreferredLanguage('user-1', CommunityLanguage.english);
    expect(
      await repository.getPreferredLanguage('user-1'),
      CommunityLanguage.english,
    );
  });
}
