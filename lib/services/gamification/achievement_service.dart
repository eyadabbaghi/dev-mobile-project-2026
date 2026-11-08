import 'package:sqflite/sqflite.dart';
import '../../database/app_database.dart';
import '../../models/gamification/achievement.dart';
import '../../models/gamification/user_gamification.dart';

class AchievementService {
  final AppDatabase _db = AppDatabase.instance;

  Future<UserGamification> getUserGamification(String userId) async {
    final database = await _db.database;
    final maps = await database.query('user_gamification', where: 'user_id = ?', whereArgs: [userId]);
    
    if (maps.isEmpty) {
      final initialData = UserGamification(userId: userId, xp: 0, level: 1, currentStreak: 0, longestStreak: 0);
      await database.insert('user_gamification', initialData.toDatabaseMap());
      return initialData;
    }
    
    return UserGamification.fromDatabaseMap(maps.first);
  }

  Future<List<Achievement>> getAchievements(String userId) async {
    final database = await _db.database;
    final rows = await database.rawQuery('''
      SELECT a.*, ua.unlocked_at 
      FROM achievements a
      LEFT JOIN user_achievements ua ON a.id = ua.achievement_id AND ua.user_id = ?
      ORDER BY a.xp_reward ASC
    ''', [userId]);

    return rows.map((r) => Achievement.fromDatabaseMap(r)).toList();
  }

  Future<Achievement?> _unlockAchievement(String userId, String achievementId, DatabaseExecutor database) async {
    // Check if already unlocked
    final existing = await database.query(
      'user_achievements',
      where: 'user_id = ? AND achievement_id = ?',
      whereArgs: [userId, achievementId],
    );

    if (existing.isNotEmpty) return null; // Already unlocked

    // Get achievement XP reward
    final achievementData = await database.query('achievements', where: 'id = ?', whereArgs: [achievementId]);
    if (achievementData.isEmpty) return null;
    final xpReward = achievementData.first['xp_reward'] as int;

    // Unlock it
    await database.insert('user_achievements', {
      'user_id': userId,
      'achievement_id': achievementId,
      'unlocked_at': DateTime.now().toIso8601String(),
    });

    // Add XP
    await _addXp(userId, xpReward, database);
    
    return Achievement.fromDatabaseMap({
      ...achievementData.first,
      'unlocked_at': DateTime.now().toIso8601String()
    });
  }

  Future<void> _addXp(String userId, int xpToAdd, DatabaseExecutor database) async {
    final stats = await database.query('user_gamification', where: 'user_id = ?', whereArgs: [userId]);
    if (stats.isEmpty) return;
    
    int currentXp = stats.first['xp'] as int;
    int currentLevel = stats.first['level'] as int;
    
    currentXp += xpToAdd;
    // Simple level formula: Level = (XP / 1000) + 1
    int newLevel = (currentXp / 1000).floor() + 1;
    if (newLevel < currentLevel) newLevel = currentLevel;

    await database.update(
      'user_gamification',
      {'xp': currentXp, 'level': newLevel},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // To be called when a user adds a weight or measurement
  Future<List<Achievement>> checkActionTriggers(String userId) async {
    final database = await _db.database;
    List<Achievement> justUnlocked = [];

    await database.transaction((txn) async {
      // 1. Update Streaks
      final gamification = await txn.query('user_gamification', where: 'user_id = ?', whereArgs: [userId]);
      if (gamification.isNotEmpty) {
        final gData = UserGamification.fromDatabaseMap(gamification.first);
        final today = DateTime.now();
        final lastAction = gData.lastActionDate;
        
        int newStreak = gData.currentStreak;
        int longest = gData.longestStreak;
        bool addedXpForAction = false;
        
        if (lastAction == null) {
          newStreak = 1;
          addedXpForAction = true;
        } else {
          final diffDays = DateTime(today.year, today.month, today.day).difference(DateTime(lastAction.year, lastAction.month, lastAction.day)).inDays;
          if (diffDays == 1) {
            newStreak++;
            addedXpForAction = true;
          } else if (diffDays > 1) {
            newStreak = 1; // Streak broken
            addedXpForAction = true;
          }
        }
        
        if (newStreak > longest) longest = newStreak;

        await txn.update(
          'user_gamification',
          {
            'current_streak': newStreak, 
            'longest_streak': longest,
            'last_action_date': "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}"
          },
          where: 'user_id = ?',
          whereArgs: [userId],
        );

        if (addedXpForAction) {
          await _addXp(userId, 10, txn); // +10 XP per daily tracking action
        }

        // 2. Check Achievements logic
        
        // "first_step"
        final weightCount = Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM weight_history WHERE user_id = ?', [userId])) ?? 0;
        if (weightCount >= 1) {
          final ach = await _unlockAchievement(userId, 'first_step', txn);
          if (ach != null) justUnlocked.add(ach);
        }

        // "dedicated_10"
        if (weightCount >= 10) {
          final ach = await _unlockAchievement(userId, 'dedicated_10', txn);
          if (ach != null) justUnlocked.add(ach);
        }

        // "consistency_7"
        if (newStreak >= 7) {
          final ach = await _unlockAchievement(userId, 'consistency_7', txn);
          if (ach != null) justUnlocked.add(ach);
        }
      }
    });

    return justUnlocked;
  }
}
