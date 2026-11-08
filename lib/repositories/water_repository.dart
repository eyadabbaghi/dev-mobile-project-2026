import '../database/app_database.dart';
import '../models/water_intake_entry.dart';

class WaterRepository {
  WaterRepository({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  static final WaterRepository instance = WaterRepository();
  final AppDatabase _database;

  (String, String) _dateRangeStrings(DateTime date) {
    final start = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    return (start.toIso8601String(), end.toIso8601String());
  }

  Future<List<WaterIntakeEntry>> getWaterEntriesForDate(
    String userId,
    DateTime date,
  ) async {
    final db = await _database.database;
    final (startStr, endStr) = _dateRangeStrings(date);

    final maps = await db.query(
      'water_intake_entries',
      where: 'user_id = ? AND consumed_at >= ? AND consumed_at <= ?',
      whereArgs: [userId, startStr, endStr],
      orderBy: 'consumed_at DESC, id DESC',
    );

    return maps.map((m) => WaterIntakeEntry.fromDatabaseMap(m)).toList();
  }

  Future<int> addWaterIntake({
    required String userId,
    required int amountMl,
    DateTime? consumedAt,
  }) async {
    if (amountMl <= 0) return 0;
    final db = await _database.database;
    final entry = WaterIntakeEntry(
      userId: userId,
      amountMl: amountMl,
      consumedAt: consumedAt ?? DateTime.now(),
    );
    return await db.insert('water_intake_entries', entry.toDatabaseMap());
  }

  Future<int> deleteWaterIntake(int id, String userId) async {
    final db = await _database.database;
    return await db.delete(
      'water_intake_entries',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  Future<int> getDailyWaterTotal(String userId, DateTime date) async {
    final db = await _database.database;
    final (startStr, endStr) = _dateRangeStrings(date);

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount_ml) as total
      FROM water_intake_entries
      WHERE user_id = ? AND consumed_at >= ? AND consumed_at <= ?
    ''',
      [userId, startStr, endStr],
    );

    if (result.isEmpty) return 0;
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }
}
