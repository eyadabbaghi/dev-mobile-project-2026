import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'seed_foods.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const int _schemaVersion = 1;
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
    );
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
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null && database.isOpen) await database.close();
  }
}
