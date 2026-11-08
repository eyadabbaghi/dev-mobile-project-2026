import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'seed_foods.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const int _schemaVersion = 6; // Bump to v6 for Meal Templates & Water Intake
  static const String _databaseName = 'fittrack_ai.db';

  Database? _database;
  Future<Database>? _opening;

  Future<Database> get database async {
    final opened = _database;
    if (opened != null && opened.isOpen) return opened;

    final opening = _opening;
    if (opening != null) return opening;

    final future = _open();
    _opening = future;
    try {
      final database = await future;
      _database = database;
      return database;
    } finally {
      _opening = null;
    }
  }

  Future<Database> _open() async {
    final directory = await getDatabasesPath();
    final databasePath = path.join(directory, _databaseName);
    return openDatabase(
      databasePath,
      version: _schemaVersion,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await database.rawQuery('PRAGMA journal_mode = WAL');
      },
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
  }

  Future<void> _upgradeSchema(Database database, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await database.execute('DROP TABLE IF EXISTS weight_history');
      await database.execute('DROP TABLE IF EXISTS user_goals');
      await database.execute('DROP TABLE IF EXISTS users');
      await _createUserTables(database);
    }
    if (oldVersion < 4) {
      await _createAdvancedTrackingAndGamificationTables(database);
    }
    if (oldVersion < 5) {
      await _createAiAndReportsTables(database);
    }
    if (oldVersion < 6) {
      await _createMealAndWaterJournalTables(database);
    }
  }

  Future<void> _createAiAndReportsTables(Database database) async {
    await database.execute('''
      CREATE TABLE ai_recommendations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        priority TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE TABLE progress_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        report_type TEXT NOT NULL,
        file_path TEXT NOT NULL,
        summary TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    
    await database.execute('CREATE INDEX ai_recs_user_idx ON ai_recommendations(user_id)');
  }

  Future<void> _createAdvancedTrackingAndGamificationTables(Database database) async {
    // Advanced Tracking
    await database.execute('''
      CREATE TABLE body_measurements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        waist_cm REAL,
        chest_cm REAL,
        arm_cm REAL,
        hip_cm REAL,
        date TEXT NOT NULL,
        UNIQUE(user_id, date),
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    
    // Gamification - User Stats (XP, Level, Streak)
    await database.execute('''
      CREATE TABLE user_gamification (
        user_id TEXT PRIMARY KEY NOT NULL,
        xp INTEGER NOT NULL DEFAULT 0,
        level INTEGER NOT NULL DEFAULT 1,
        current_streak INTEGER NOT NULL DEFAULT 0,
        longest_streak INTEGER NOT NULL DEFAULT 0,
        last_action_date TEXT,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // Achievements Catalog (Static definition of badges)
    await database.execute('''
      CREATE TABLE achievements (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        icon_name TEXT NOT NULL,
        xp_reward INTEGER NOT NULL
      )
    ''');
    
    // User Unlocked Achievements
    await database.execute('''
      CREATE TABLE user_achievements (
        user_id TEXT NOT NULL,
        achievement_id TEXT NOT NULL,
        unlocked_at TEXT NOT NULL,
        PRIMARY KEY(user_id, achievement_id),
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY(achievement_id) REFERENCES achievements(id) ON DELETE CASCADE
      )
    ''');
    
    // Seed initial achievements
    final batch = database.batch();
    batch.insert('achievements', {'id': 'first_step', 'title': 'Premier Pas', 'description': 'Enregistrez votre première pesée.', 'icon_name': 'emoji_events', 'xp_reward': 50});
    batch.insert('achievements', {'id': 'consistency_7', 'title': 'Régulier', 'description': '7 jours consécutifs de suivi.', 'icon_name': 'local_fire_department', 'xp_reward': 150});
    batch.insert('achievements', {'id': 'dedicated_10', 'title': 'Dédié', 'description': '10 mesures enregistrées.', 'icon_name': 'star', 'xp_reward': 200});
    batch.insert('achievements', {'id': 'goal_50', 'title': 'Mi-chemin', 'description': '50% de l\'objectif atteint.', 'icon_name': 'timeline', 'xp_reward': 300});
    batch.insert('achievements', {'id': 'goal_master', 'title': 'Maître de l\'objectif', 'description': 'Objectif atteint !', 'icon_name': 'military_tech', 'xp_reward': 1000});
    await batch.commit(noResult: true);
  }

  Future<void> _createUserTables(Database database) async {
    await database.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        birth_date TEXT,
        gender TEXT,
        height_cm REAL,
        initial_weight_kg REAL,
        activity_level TEXT,
        profile_picture_path TEXT,
        is_onboarded INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE user_goals (
        user_id TEXT PRIMARY KEY NOT NULL,
        goal_type TEXT NOT NULL,
        target_weight_kg REAL NOT NULL,
        daily_calories INTEGER NOT NULL,
        protein_grams INTEGER NOT NULL,
        carbs_grams INTEGER NOT NULL,
        fat_grams INTEGER NOT NULL,
        daily_water_ml INTEGER NOT NULL,
        is_manual INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE TABLE weight_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        date TEXT NOT NULL,
        UNIQUE(user_id, date),
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    
    await database.execute('CREATE INDEX weight_history_user_idx ON weight_history(user_id)');
  }

  Future<void> _createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE foods (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL CHECK(length(trim(name)) > 0),
        brand TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL,
        reference_portion TEXT NOT NULL,
        unit TEXT NOT NULL CHECK(unit IN ('gram', 'milliliter')),
        calories_per_100 REAL NOT NULL CHECK(calories_per_100 >= 0),
        protein_per_100 REAL NOT NULL CHECK(protein_per_100 >= 0),
        carbohydrate_per_100 REAL NOT NULL CHECK(carbohydrate_per_100 >= 0),
        fat_per_100 REAL NOT NULL CHECK(fat_per_100 >= 0),
        owner_id TEXT,
        barcode TEXT UNIQUE,
        is_builtin INTEGER NOT NULL DEFAULT 0 CHECK(is_builtin IN (0, 1)),
        nutrition_is_complete INTEGER NOT NULL DEFAULT 1 CHECK(nutrition_is_complete IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await database.execute(
      'CREATE INDEX foods_name_idx ON foods(name COLLATE NOCASE)',
    );
    await database.execute(
      'CREATE INDEX foods_category_idx ON foods(category)',
    );
    await database.execute('CREATE INDEX foods_owner_idx ON foods(owner_id)');
    await database.execute('''
      CREATE TABLE food_favorites (
        user_id TEXT NOT NULL,
        food_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY(user_id, food_id),
        FOREIGN KEY(food_id) REFERENCES foods(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE meal_food_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        food_name TEXT NOT NULL,
        brand TEXT NOT NULL DEFAULT '',
        amount REAL NOT NULL CHECK(amount > 0),
        unit TEXT NOT NULL CHECK(unit IN ('gram', 'milliliter')),
        calories REAL NOT NULL CHECK(calories >= 0),
        protein_grams REAL NOT NULL CHECK(protein_grams >= 0),
        carbohydrate_grams REAL NOT NULL CHECK(carbohydrate_grams >= 0),
        fat_grams REAL NOT NULL CHECK(fat_grams >= 0),
        meal_slot TEXT NOT NULL,
        consumed_at TEXT NOT NULL
      )
    ''');
    await database.execute(
      'CREATE INDEX meal_entries_user_date_idx ON meal_food_entries(user_id, consumed_at)',
    );

    final batch = database.batch();
    for (final food in builtInFoods) {
      batch.insert('foods', food, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
    
    // Also create user tables on fresh install
    await _createUserTables(database);
    await _createAdvancedTrackingAndGamificationTables(database);
    await _createAiAndReportsTables(database);
    await _createMealAndWaterJournalTables(database);
  }

  Future<void> _createMealAndWaterJournalTables(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS water_intake_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        amount_ml INTEGER NOT NULL CHECK(amount_ml > 0),
        consumed_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS water_entries_user_date_idx ON water_intake_entries(user_id, consumed_at)',
    );

    await database.execute('''
      CREATE TABLE IF NOT EXISTS meal_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        meal_slot TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE TABLE IF NOT EXISTS meal_template_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL,
        food_name TEXT NOT NULL,
        brand TEXT NOT NULL DEFAULT '',
        amount REAL NOT NULL CHECK(amount > 0),
        unit TEXT NOT NULL CHECK(unit IN ('gram', 'milliliter')),
        calories REAL NOT NULL CHECK(calories >= 0),
        protein_grams REAL NOT NULL CHECK(protein_grams >= 0),
        carbohydrate_grams REAL NOT NULL CHECK(carbohydrate_grams >= 0),
        fat_grams REAL NOT NULL CHECK(fat_grams >= 0),
        FOREIGN KEY(template_id) REFERENCES meal_templates(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null && database.isOpen) await database.close();
  }
}
