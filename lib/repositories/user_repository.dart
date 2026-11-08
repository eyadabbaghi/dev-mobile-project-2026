import 'package:sqflite/sqflite.dart';
import '../models/user.dart';
import '../models/user_goal.dart';
import '../models/weight_entry.dart';
import '../database/app_database.dart';

class UserRepository {
  final AppDatabase _database = AppDatabase.instance;

  Future<User?> getUserByEmail(String email) async {
    final db = await _database.database;
    final maps = await db.query('users', where: 'email = ?', whereArgs: [email.toLowerCase()]);
    if (maps.isEmpty) return null;
    return User.fromDatabaseMap(maps.first);
  }

  Future<User?> getUserById(String id) async {
    final db = await _database.database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return User.fromDatabaseMap(maps.first);
  }

  Future<void> createUserOnly(User user) async {
    final db = await _database.database;
    await db.insert('users', user.toDatabaseMap(), conflictAlgorithm: ConflictAlgorithm.fail);
  }

  Future<void> updateUserAndGoals(User user, UserGoal goal) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.update('users', user.toDatabaseMap(), where: 'id = ?', whereArgs: [user.id]);
      await txn.insert('user_goals', goal.toDatabaseMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> updateUser(User user) async {
    final db = await _database.database;
    await db.update('users', user.toDatabaseMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  Future<UserGoal?> getUserGoal(String userId) async {
    final db = await _database.database;
    final maps = await db.query('user_goals', where: 'user_id = ?', whereArgs: [userId]);
    if (maps.isEmpty) return null;
    return UserGoal.fromDatabaseMap(maps.first);
  }

  Future<void> addOrUpdateWeight(WeightEntry entry) async {
    final db = await _database.database;
    await db.insert('weight_history', entry.toDatabaseMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<WeightEntry>> getWeightHistory(String userId) async {
    final db = await _database.database;
    final maps = await db.query('weight_history', where: 'user_id = ?', whereArgs: [userId], orderBy: 'date ASC');
    return maps.map((m) => WeightEntry.fromDatabaseMap(m)).toList();
  }
}
