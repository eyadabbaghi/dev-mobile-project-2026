import '../database/app_database.dart';
import '../models/meal_food_entry.dart';
import '../models/meal_template.dart';

class MealJournalRepository {
  MealJournalRepository({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  static final MealJournalRepository instance = MealJournalRepository();
  final AppDatabase _database;

  /// Returns start and end timestamps for a given calendar date.
  (String, String) _dateRangeStrings(DateTime date) {
    final start = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    return (start.toIso8601String(), end.toIso8601String());
  }

  Future<List<MealFoodEntry>> getEntriesForDate(
    String userId,
    DateTime date,
  ) async {
    final db = await _database.database;
    final (startStr, endStr) = _dateRangeStrings(date);

    final maps = await db.query(
      'meal_food_entries',
      where: 'user_id = ? AND consumed_at >= ? AND consumed_at <= ?',
      whereArgs: [userId, startStr, endStr],
      orderBy: 'consumed_at ASC, id ASC',
    );

    return maps.map((m) => MealFoodEntry.fromDatabaseMap(m)).toList();
  }

  Future<int> addMealEntry(MealFoodEntry entry) async {
    final db = await _database.database;
    return await db.insert('meal_food_entries', entry.toDatabaseMap());
  }

  Future<int> updateMealEntry(MealFoodEntry entry) async {
    if (entry.id == null) return 0;
    final db = await _database.database;
    return await db.update(
      'meal_food_entries',
      entry.toDatabaseMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [entry.id, entry.userId],
    );
  }

  Future<int> deleteMealEntry(int id, String userId) async {
    final db = await _database.database;
    return await db.delete(
      'meal_food_entries',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  /// Duplicates all meal entries for a specific slot from `fromDate` to `toDate` (MEA07).
  Future<void> copyMealSlot({
    required String userId,
    required MealSlot slot,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final db = await _database.database;
    final (startStr, endStr) = _dateRangeStrings(fromDate);

    final maps = await db.query(
      'meal_food_entries',
      where:
          'user_id = ? AND meal_slot = ? AND consumed_at >= ? AND consumed_at <= ?',
      whereArgs: [userId, slot.name, startStr, endStr],
    );

    if (maps.isEmpty) return;

    final targetConsumedAt = DateTime(
      toDate.year,
      toDate.month,
      toDate.day,
      DateTime.now().hour,
      DateTime.now().minute,
    );

    await db.transaction((txn) async {
      for (final map in maps) {
        final original = MealFoodEntry.fromDatabaseMap(map);
        final copy = MealFoodEntry(
          userId: userId,
          foodName: original.foodName,
          brand: original.brand,
          amount: original.amount,
          unit: original.unit,
          calories: original.calories,
          proteinGrams: original.proteinGrams,
          carbohydrateGrams: original.carbohydrateGrams,
          fatGrams: original.fatGrams,
          mealSlot: slot,
          consumedAt: targetConsumedAt,
        );
        await txn.insert('meal_food_entries', copy.toDatabaseMap());
      }
    });
  }

  /// Saves a list of meal food entries as a reusable template (MEA06).
  Future<int> saveMealSlotAsTemplate({
    required String userId,
    required String templateName,
    required MealSlot slot,
    required List<MealFoodEntry> entries,
  }) async {
    if (entries.isEmpty) return 0;
    final db = await _database.database;

    late int templateId;
    await db.transaction((txn) async {
      final template = MealTemplate(
        userId: userId,
        name: templateName,
        mealSlot: slot,
        createdAt: DateTime.now(),
      );

      templateId = await txn.insert('meal_templates', template.toDatabaseMap());

      for (final entry in entries) {
        final item = MealTemplateItem.fromMealFoodEntry(entry);
        await txn.insert('meal_template_items', item.toDatabaseMap(templateId));
      }
    });

    return templateId;
  }

  /// Lists all saved meal templates for a user (MEA06).
  Future<List<MealTemplate>> getTemplates(String userId) async {
    final db = await _database.database;

    final templateMaps = await db.query(
      'meal_templates',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    if (templateMaps.isEmpty) return [];

    final result = <MealTemplate>[];
    for (final map in templateMaps) {
      final templateId = map['id'] as int;
      final itemMaps = await db.query(
        'meal_template_items',
        where: 'template_id = ?',
        whereArgs: [templateId],
      );
      final items =
          itemMaps.map((i) => MealTemplateItem.fromDatabaseMap(i)).toList();
      result.add(MealTemplate.fromDatabaseMap(map, items));
    }

    return result;
  }

  /// Applies a template into a target meal slot at targetDate (MEA06, RG06).
  Future<void> applyTemplateToMealSlot({
    required String userId,
    required int templateId,
    required MealSlot targetSlot,
    required DateTime targetDate,
  }) async {
    final db = await _database.database;

    final itemMaps = await db.query(
      'meal_template_items',
      where: 'template_id = ?',
      whereArgs: [templateId],
    );

    if (itemMaps.isEmpty) return;

    final targetConsumedAt = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      DateTime.now().hour,
      DateTime.now().minute,
    );

    await db.transaction((txn) async {
      for (final itemMap in itemMaps) {
        final item = MealTemplateItem.fromDatabaseMap(itemMap);
        final entry = item.toMealFoodEntry(
          userId: userId,
          mealSlot: targetSlot,
          consumedAt: targetConsumedAt,
        );
        await txn.insert('meal_food_entries', entry.toDatabaseMap());
      }
    });
  }

  /// Deletes a saved meal template (MEA06).
  Future<int> deleteTemplate(int templateId, String userId) async {
    final db = await _database.database;
    return await db.delete(
      'meal_templates',
      where: 'id = ? AND user_id = ?',
      whereArgs: [templateId, userId],
    );
  }
}
