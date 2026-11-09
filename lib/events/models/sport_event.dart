enum EventCategory { sport, health, nutrition, running }

extension EventCategoryLabel on EventCategory {
  String get label => switch (this) {
    EventCategory.sport => 'Sport',
    EventCategory.health => 'Santé',
    EventCategory.nutrition => 'Nutrition',
    EventCategory.running => 'Running',
  };
}

enum EventMode { inPerson, online, hybrid }

extension EventModeLabel on EventMode {
  String get label => switch (this) {
    EventMode.inPerson => 'Présentiel',
    EventMode.online => 'En ligne',
    EventMode.hybrid => 'Hybride',
  };
}

class SportEvent {
  SportEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.dateTime,
    required this.mode,
    required this.city,
    required this.location,
    required this.price,
    required this.capacity,
    required this.coachId,
    required this.coachName,
    required this.latitude,
    required this.longitude,
    this.imagePath,
    List<String>? attendeeIds,
    List<String>? waitlistIds,
    Set<String>? checkedInIds,
  }) : attendeeIds = attendeeIds ?? [],
       waitlistIds = waitlistIds ?? [],
       checkedInIds = checkedInIds ?? {};

  /// Reconstruit un événement depuis une ligne de la table `events`.
  /// Les listes d'inscrits sont remplies à part (table `event_registrations`).
  factory SportEvent.fromMap(Map<String, Object?> map) => SportEvent(
    id: map['id'] as String,
    title: map['title'] as String,
    description: map['description'] as String,
    category: EventCategory.values.byName(map['category'] as String),
    dateTime: DateTime.fromMillisecondsSinceEpoch(map['date_time'] as int),
    mode: EventMode.values.byName(map['mode'] as String),
    city: map['city'] as String,
    location: map['location'] as String,
    imagePath: map['image_path'] as String?,
    price: (map['price'] as num).toDouble(),
    capacity: map['capacity'] as int,
    coachId: map['coach_id'] as String,
    coachName: map['coach_name'] as String,
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
  );

  final String id;
  final String title;
  final String description;
  final EventCategory category;
  final DateTime dateTime;
  final EventMode mode;
  final String city;
  final String location;
  final String? imagePath;
  final double price;
  final int capacity;
  final String coachId;
  final String coachName;
  final double latitude;
  final double longitude;
  final List<String> attendeeIds;
  final List<String> waitlistIds;
  final Set<String> checkedInIds;

  bool get isFree => price <= 0;
  bool get isFull => attendeeIds.length >= capacity;

  SportEvent copyWithImagePath(String? path) => SportEvent(
    id: id,
    title: title,
    description: description,
    category: category,
    dateTime: dateTime,
    mode: mode,
    city: city,
    location: location,
    imagePath: path,
    price: price,
    capacity: capacity,
    coachId: coachId,
    coachName: coachName,
    latitude: latitude,
    longitude: longitude,
    attendeeIds: attendeeIds,
    waitlistIds: waitlistIds,
    checkedInIds: checkedInIds,
  );

  SportEvent copyWithCoordinates({
    required double latitude,
    required double longitude,
  }) => SportEvent(
    id: id,
    title: title,
    description: description,
    category: category,
    dateTime: dateTime,
    mode: mode,
    city: city,
    location: location,
    imagePath: imagePath,
    price: price,
    capacity: capacity,
    coachId: coachId,
    coachName: coachName,
    latitude: latitude,
    longitude: longitude,
    attendeeIds: attendeeIds,
    waitlistIds: waitlistIds,
    checkedInIds: checkedInIds,
  );

  /// Rang dans la liste d'attente (1 = premier). Retourne 0 si absent de la liste.
  int waitlistRank(String userId) {
    final index = waitlistIds.indexOf(userId);
    return index < 0 ? 0 : index + 1;
  }

  /// Ligne pour la table `events` (sans les inscriptions).
  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category.name,
    'date_time': dateTime.millisecondsSinceEpoch,
    'mode': mode.name,
    'city': city,
    'location': location,
    'image_path': imagePath,
    'price': price,
    'capacity': capacity,
    'coach_id': coachId,
    'coach_name': coachName,
    'latitude': latitude,
    'longitude': longitude,
  };

  String toIcs() {
    final start = dateTime.toUtc();
    final end = start.add(const Duration(hours: 1));
    String format(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}T'
        '${value.hour.toString().padLeft(2, '0')}'
        '${value.minute.toString().padLeft(2, '0')}'
        '${value.second.toString().padLeft(2, '0')}Z';

    String escape(String value) => value
        .replaceAll(r'\', r'\\')
        .replaceAll(',', r'\,')
        .replaceAll(';', r'\;')
        .replaceAll('\n', r'\n');

    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//FitTrack AI//Events//FR',
      'BEGIN:VEVENT',
      'UID:$id@fittrack-ai',
      'DTSTAMP:${format(DateTime.now().toUtc())}',
      'DTSTART:${format(start)}',
      'DTEND:${format(end)}',
      'SUMMARY:${escape(title)}',
      'DESCRIPTION:${escape(description)}',
      'LOCATION:${escape('$location, $city')}',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');
  }
}

class EventUser {
  const EventUser({
    required this.id,
    required this.name,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.activityLevel,
    required this.goals,
    required this.interests,
    this.isCoach = false,
  });

  final String id;
  final String name;
  final String city;
  final double latitude;
  final double longitude;
  final String activityLevel;
  final List<String> goals;
  final List<EventCategory> interests;
  final bool isCoach;
}
