class WeightEntry {
  final int? id;
  final String userId;
  final double weightKg;
  final DateTime date;

  const WeightEntry({
    this.id,
    required this.userId,
    required this.weightKg,
    required this.date,
  });

  Map<String, dynamic> toDatabaseMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'weight_kg': weightKg,
      // On sauvegarde juste la date (YYYY-MM-DD) pour garantir l'unicité par jour
      'date': "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
    };
  }

  factory WeightEntry.fromDatabaseMap(Map<String, dynamic> map) {
    return WeightEntry(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      weightKg: (map['weight_kg'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
    );
  }
}
