import 'package:sqflite/sqflite.dart';
import '../../database/app_database.dart';
import '../../models/ai_recommendation.dart';
import '../../repositories/user_repository.dart';

class AiRecommendationService {
  final AppDatabase _db = AppDatabase.instance;
  final UserRepository _userRepo = UserRepository();

  Future<List<AiRecommendation>> getRecommendations(String userId) async {
    final database = await _db.database;
    
    // Générer des recommandations dynamiques basées sur l'état actuel de l'utilisateur
    await _generateContextualInsights(userId, database);

    final maps = await database.query(
      'ai_recommendations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    return maps.map((m) => AiRecommendation.fromDatabaseMap(m)).toList();
  }

  Future<void> _generateContextualInsights(String userId, Database database) async {
    final user = await _userRepo.getUserById(userId);
    if (user == null) return;

    final weights = await _userRepo.getWeightHistory(userId);
    final goal = await _userRepo.getUserGoal(userId);

    // Vérifier s'il y a déjà des recommandations récentes (pour éviter le spam)
    final recent = await database.query(
      'ai_recommendations',
      where: 'user_id = ? AND created_at >= ?',
      whereArgs: [userId, DateTime.now().subtract(const Duration(days: 1)).toIso8601String()],
    );

    if (recent.isNotEmpty) return; // Assez récent

    // Règle 1 : Absence de pesée récente (> 5 jours)
    if (weights.isNotEmpty) {
      final lastWeightDate = weights.last.date;
      final diffDays = DateTime.now().difference(lastWeightDate).inDays;
      if (diffDays >= 5) {
        await database.insert('ai_recommendations', AiRecommendation(
          userId: userId,
          title: 'Rappel de pesée ⚖️',
          description: 'Vous n\'avez pas enregistré de poids depuis $diffDays jours. La régularité est la clé du succès !',
          category: 'tracking',
          priority: 'high',
          isRead: false,
          createdAt: DateTime.now(),
        ).toDatabaseMap());
      }
    }

    // Règle 2 : Analyse de progression vers l'objectif
    if (goal != null && weights.length >= 2) {
      final initial = weights.first.weightKg;
      final current = weights.last.weightKg;
      final target = goal.targetWeightKg;

      if (goal.goalType == 'weight_loss' && current > initial) {
        await database.insert('ai_recommendations', AiRecommendation(
          userId: userId,
          title: 'Tendance à la hausse 📈',
          description: 'Votre poids a légèrement augmenté depuis votre départ. Vérifiez vos apports caloriques journaliers dans le catalogue.',
          category: 'nutrition',
          priority: 'medium',
          isRead: false,
          createdAt: DateTime.now(),
        ).toDatabaseMap());
      } else if (goal.goalType == 'weight_loss' && current <= target) {
        await database.insert('ai_recommendations', AiRecommendation(
          userId: userId,
          title: 'Objectif atteint ! 🎉',
          description: 'Félicitations, vous avez atteint votre poids cible. Pensez à basculer vers un mode "Maintien".',
          category: 'goal',
          priority: 'high',
          isRead: false,
          createdAt: DateTime.now(),
        ).toDatabaseMap());
      }
    }

    // Règle 3 : Hydratation / Eau conseillée
    if (user.initialWeightKg != null) {
      final waterMl = (user.initialWeightKg! * 35).round();
      await database.insert('ai_recommendations', AiRecommendation(
        userId: userId,
        title: 'Conseil Hydratation 💧',
        description: 'Pour votre poids actuel, visez environ ${waterMl}ml d\'eau par jour pour optimiser votre métabolisme.',
        category: 'nutrition',
        priority: 'low',
        isRead: false,
        createdAt: DateTime.now(),
      ).toDatabaseMap());
    }
  }

  Future<void> markAsRead(int id) async {
    final database = await _db.database;
    await database.update(
      'ai_recommendations',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
