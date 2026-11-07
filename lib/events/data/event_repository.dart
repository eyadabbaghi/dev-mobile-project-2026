import 'package:sqflite/sqflite.dart';

import '../models/sport_event.dart';
import 'event_database.dart';
import 'event_image_storage.dart';

/// Seul point d'accès aux données des événements.
/// Chaque méthode écrit en base ET met à jour l'objet [SportEvent] en mémoire,
/// pour que l'interface reste synchronisée sans tout recharger.
class EventRepository {
  EventRepository({EventDatabase? database})
    : _database = database ?? EventDatabase.instance;

  final EventDatabase _database;

  static const _confirmed = 'CONFIRMED';
  static const _waiting = 'WAITING_LIST';
  static const _attended = 'ATTENDED';

  Future<List<SportEvent>> getEvents() async {
    final db = await _database.database;
    final eventRows = await db.query('events');
    final registrationRows = await db.query(
      'event_registrations',
      orderBy: 'id ASC',
    );

    final events = eventRows.map(SportEvent.fromMap).toList();
    final byId = {for (final event in events) event.id: event};

    for (final row in registrationRows) {
      final event = byId[row['event_id']];
      if (event == null) continue;
      final userId = row['user_id'] as String;
      switch (row['status']) {
        case _waiting:
          event.waitlistIds.add(userId);
        case _attended:
          event.attendeeIds.add(userId);
          event.checkedInIds.add(userId);
        default:
          event.attendeeIds.add(userId);
      }
    }
    return events;
  }

  Future<void> insertEvent(SportEvent event) async {
    final db = await _database.database;
    await db.insert(
      'events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Supprime l'événement et ses inscriptions (ON DELETE CASCADE).
  Future<void> deleteEvent(String eventId) async {
    final db = await _database.database;
    final rows = await db.query(
      'events',
      columns: ['image_path'],
      where: 'id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    await db.delete('events', where: 'id = ?', whereArgs: [eventId]);
    if (rows.isNotEmpty) {
      await EventImageStorage.instance.deleteImage(
        rows.first['image_path'] as String?,
      );
    }
  }

  /// Inscrit, désinscrit ou gère la liste d'attente. Retourne le message à afficher.
  Future<String> toggleRegistration(SportEvent event, String userId) async {
    final db = await _database.database;

    if (event.attendeeIds.contains(userId)) {
      await _removeRegistration(db, event.id, userId);
      event.attendeeIds.remove(userId);
      event.checkedInIds.remove(userId);
      await _promoteFirstWaiting(db, event);
      return 'Inscription annulée.';
    }

    if (event.waitlistIds.contains(userId)) {
      await _removeRegistration(db, event.id, userId);
      event.waitlistIds.remove(userId);
      return 'Retiré de la liste d’attente.';
    }

    final isFull = event.isFull;
    await db.insert('event_registrations', {
      'event_id': event.id,
      'user_id': userId,
      'status': isFull ? _waiting : _confirmed,
      'registered_at': DateTime.now().millisecondsSinceEpoch,
    });

    if (isFull) {
      event.waitlistIds.add(userId);
      final rank = event.waitlistRank(userId);
      return 'Événement complet : ajouté à la liste d’attente (rang $rank).';
    }
    event.attendeeIds.add(userId);
    return 'Inscription confirmée.';
  }

  /// Pointage de présence par le coach.
  Future<void> setCheckedIn(
    SportEvent event,
    String userId,
    bool checkedIn,
  ) async {
    final db = await _database.database;
    await db.update(
      'event_registrations',
      {'status': checkedIn ? _attended : _confirmed},
      where: 'event_id = ? AND user_id = ?',
      whereArgs: [event.id, userId],
    );
    if (checkedIn) {
      event.checkedInIds.add(userId);
    } else {
      event.checkedInIds.remove(userId);
    }
  }

  Future<void> _removeRegistration(
    Database db,
    String eventId,
    String userId,
  ) => db.delete(
    'event_registrations',
    where: 'event_id = ? AND user_id = ?',
    whereArgs: [eventId, userId],
  );

  /// RG07 : quand une place se libère, le premier de la liste d'attente est confirmé.
  Future<void> _promoteFirstWaiting(Database db, SportEvent event) async {
    if (event.waitlistIds.isEmpty || event.isFull) return;
    final nextUserId = event.waitlistIds.first;
    await db.update(
      'event_registrations',
      {'status': _confirmed},
      where: 'event_id = ? AND user_id = ?',
      whereArgs: [event.id, nextUserId],
    );
    event.waitlistIds.removeAt(0);
    event.attendeeIds.add(nextUserId);
  }
}
