import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWeb;

import '../../models/user.dart';
import '../../theme/fit_theme.dart';
import '../data/community_repository.dart';
import '../models/community_reaction.dart';
import '../models/post.dart';
import '../screens/community_feed_screen.dart';

/// Point d'entrée de démonstration du Module 5 uniquement.
///
/// Il ne remplace pas `lib/main.dart` : il permet de lancer le fil
/// communautaire seul, sans passer par l'inscription / l'onboarding, pour
/// vérifier rapidement PUB01 → PUB05.
///
/// ```powershell
/// flutter run -t lib/community/demo/main.dart -d chrome
/// ```
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  await _seedDemoPosts();

  runApp(const CommunityDemoApp());
}

final demoUser = User(
  id: 'demo-user',
  firstName: 'Afnen',
  lastName: 'Ben Yakhlef',
  email: 'demo@fittrack.tn',
  passwordHash: '',
  isOnboarded: true,
  createdAt: DateTime(2026),
);

Future<void> _seedDemoPosts() async {
  try {
    final repository = CommunityRepository();
    final existing = await repository.getFeed(currentUserId: demoUser.id);
    if (existing.isNotEmpty) return;

    // Profils utilisés pour les @mentions et les notifications du module.
    await repository.saveProfile(
      userId: 'demo-friend',
      displayName: 'Sami Trabelsi',
    );
    await repository.saveProfile(
      userId: 'demo-coach',
      displayName: 'Nina Gharbi',
    );

    final meal = await repository.createPost(
      userId: demoUser.id,
      authorName: 'Afnen Ben Yakhlef',
      content:
          'Salade poulet, quinoa et avocat après la séance. ~520 kcal bien '
          'équilibrées 💪 #nutrition #mealprep @sami_trabelsi',
      theme: PostTheme.meal,
    );
    final mealComment = await repository.addComment(
      postId: meal.id,
      userId: 'demo-friend',
      authorName: 'Sami Trabelsi',
      content: 'Super idée de repas, je teste demain !',
    );
    await repository.addComment(
      postId: meal.id,
      userId: demoUser.id,
      authorName: 'Afnen Ben Yakhlef',
      content: 'Dis-moi ce que tu en penses, je peux partager la recette.',
      parentId: mealComment.id,
    );
    await repository.addComment(
      postId: meal.id,
      userId: 'demo-coach',
      authorName: 'Nina Gharbi',
      content: 'Parfait pour le post-entraînement, bravo pour l’équilibre !',
    );
    await repository.toggleReaction(
      postId: meal.id,
      userId: 'demo-friend',
      reaction: CommunityReaction.love,
      actorName: 'Sami Trabelsi',
    );
    await repository.toggleReaction(
      postId: meal.id,
      userId: 'demo-coach',
      reaction: CommunityReaction.wow,
      actorName: 'Nina Gharbi',
    );
    await repository.toggleCommentReaction(
      commentId: mealComment.id,
      userId: demoUser.id,
      reaction: CommunityReaction.like,
      actorName: 'Afnen Ben Yakhlef',
    );
    await repository.togglePinComment(
      commentId: mealComment.id,
      postId: meal.id,
      userId: demoUser.id,
    );
    await repository.toggleBestAnswer(
      commentId: mealComment.id,
      postId: meal.id,
      userId: demoUser.id,
    );
    await repository.togglePinPost(postId: meal.id, userId: demoUser.id);
    final collection = await repository.createCollection(
      userId: demoUser.id,
      name: 'Recettes',
    );
    await repository.toggleBookmark(
      postId: meal.id,
      userId: demoUser.id,
      collectionId: collection.id,
    );

    final sport = await repository.createPost(
      userId: demoUser.id,
      authorName: 'Afnen Ben Yakhlef',
      content:
          '3 séances de musculation cette semaine et +2 kg au développé couché. '
          'La régularité paie. #sport #progress',
      theme: PostTheme.sport,
      allowAnonymousComments: true,
      pollQuestion: 'Quel type de séance préférez-vous ?',
      pollOptions: const [
        'Musculation',
        'Cardio / HIIT',
        'Mobilité & yoga',
      ],
      pollEndsAt: DateTime.now().add(const Duration(days: 5)),
    );
    final sportPoll = (await repository.getPost(sport.id, demoUser.id))?.poll;
    if (sportPoll != null && sportPoll.options.isNotEmpty) {
      await repository.votePoll(
        postId: sport.id,
        optionId: sportPoll.options.first.id,
        userId: demoUser.id,
        actorName: 'Afnen Ben Yakhlef',
      );
      await repository.votePoll(
        postId: sport.id,
        optionId: sportPoll.options.first.id,
        userId: 'demo-friend',
        actorName: 'Sami Trabelsi',
      );
      await repository.votePoll(
        postId: sport.id,
        optionId: sportPoll.options[1].id,
        userId: 'demo-coach',
        actorName: 'Nina Gharbi',
      );
    }
    await repository.registerShare(postId: sport.id, userId: 'demo-friend');

    await repository.createPost(
      userId: 'demo-friend',
      authorName: 'Sami Trabelsi',
      content:
          'Astuce nutrition : préparer ses repas le dimanche évite les écarts '
          'en semaine. @afnen_ben_yakhlef je te recommande de tester ! '
          '#nutrition #mealprep',
      theme: PostTheme.nutrition,
    );

    await repository.createPost(
      userId: demoUser.id,
      authorName: 'Afnen Ben Yakhlef',
      content:
          'Brouillon : idées de recettes riches en protéines pour la semaine '
          'prochaine.',
      theme: PostTheme.nutrition,
      isDraft: true,
    );
  } catch (error) {
    debugPrint('Seed demo impossible : $error');
  }
}

class CommunityDemoApp extends StatelessWidget {
  const CommunityDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitTrack AI — Publications (démo)',
      debugShowCheckedModeBanner: false,
      theme: FitTheme.dark,
      home: Scaffold(body: CommunityFeedScreen(user: demoUser)),
    );
  }
}
