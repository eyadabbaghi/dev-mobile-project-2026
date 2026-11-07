import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'demo_event_data.dart';

/// Ouvre la base SQLite locale du module Événements (une seule instance).
class EventDatabase {
  EventDatabase._();

  static final EventDatabase instance = EventDatabase._();

  /// Pour les tests : mettre `inMemoryDatabasePath` avant le premier accès.
  static String? pathOverride;

  static const _fileName = 'fittrack_events.db';
  static const _version = 2;

  Future<Database>? _opening;

  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final path = pathOverride ?? p.join(await getDatabasesPath(), _fileName);
    return openDatabase(
      path,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        date_time INTEGER NOT NULL,
        mode TEXT NOT NULL,
        city TEXT NOT NULL,
        location TEXT NOT NULL,
        price REAL NOT NULL,
        capacity INTEGER NOT NULL,
        coach_id TEXT NOT NULL,
        coach_name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        image_path TEXT
      )
    ''');

    // status : CONFIRMED | WAITING_LIST | ATTENDED (comme RegistrationStatus de l'UML).
    // Le rang en liste d'attente = ordre d'insertion (colonne id).
    await db.execute('''
      CREATE TABLE event_registrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
        user_id TEXT NOT NULL,
        status TEXT NOT NULL,
        registered_at INTEGER NOT NULL,
        UNIQUE (event_id, user_id)
      )
    ''');

    await _seedDemoData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE events ADD COLUMN image_path TEXT');
    }
  }

  /// Insère les 4 événements de démo à la toute première création de la base.
  Future<void> _seedDemoData(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final event in createDemoEvents()) {
      batch.insert('events', event.toMap());
      for (final userId in event.attendeeIds) {
        batch.insert('event_registrations', {
          'event_id': event.id,
          'user_id': userId,
          'status': 'CONFIRMED',
          'registered_at': now,
        });
      }
      for (final userId in event.waitlistIds) {
        batch.insert('event_registrations', {
          'event_id': event.id,
          'user_id': userId,
          'status': 'WAITING_LIST',
          'registered_at': now,
        });
      }
    }
    await batch.commit(noResult: true);
  }
}
