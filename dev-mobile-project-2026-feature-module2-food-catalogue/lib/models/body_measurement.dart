class BodyMeasurement {
  final int? id;
  final String userId;
  final double? waistCm;
  final double? chestCm;
  final double? armCm;
  final double? hipCm;
  final DateTime date;

  const BodyMeasurement({
    this.id,
    required this.userId,
    this.waistCm,
    this.chestCm,
    this.armCm,
    this.hipCm,
    required this.date,
  });

  Map<String, dynamic> toDatabaseMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'waist_cm': waistCm,
      'chest_cm': chestCm,
      'arm_cm': armCm,
      'hip_cm': hipCm,
      'date': "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
    };
  }

  factory BodyMeasurement.fromDatabaseMap(Map<String, dynamic> map) {
    return BodyMeasurement(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      waistCm: map['waist_cm'] != null ? (map['waist_cm'] as num).toDouble() : null,
      chestCm: map['chest_cm'] != null ? (map['chest_cm'] as num).toDouble() : null,
      armCm: map['arm_cm'] != null ? (map['arm_cm'] as num).toDouble() : null,
      hipCm: map['hip_cm'] != null ? (map['hip_cm'] as num).toDouble() : null,
      date: DateTime.parse(map['date'] as String),
    );
  }
}