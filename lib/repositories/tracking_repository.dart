import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/body_measurement.dart';

class TrackingRepository {
  final AppDatabase _db = AppDatabase.instance;

  Future<void> addMeasurement(BodyMeasurement measurement) async {
    final database = await _db.database;
    await database.insert(
      'body_measurements', 
      measurement.toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BodyMeasurement>> getMeasurements(String userId) async {
    final database = await _db.database;
    final maps = await database.query(
      'body_measurements',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date ASC',
    );
    return maps.map((m) => BodyMeasurement.fromDatabaseMap(m)).toList();
  }
}