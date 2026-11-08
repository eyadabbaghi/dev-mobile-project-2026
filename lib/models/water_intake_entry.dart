import 'package:flutter/foundation.dart';

@immutable
class WaterIntakeEntry {
  const WaterIntakeEntry({
    this.id,
    required this.userId,
    required this.amountMl,
    required this.consumedAt,
  });

  final int? id;
  final String userId;
  final int amountMl;
  final DateTime consumedAt;

  Map<String, Object?> toDatabaseMap() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'amount_ml': amountMl,
    'consumed_at': consumedAt.toIso8601String(),
  };

  factory WaterIntakeEntry.fromDatabaseMap(Map<String, Object?> map) {
    return WaterIntakeEntry(
      id: (map['id'] as num?)?.toInt(),
      userId: map['user_id'] as String? ?? '',
      amountMl: (map['amount_ml'] as num?)?.toInt() ?? 0,
      consumedAt:
          DateTime.tryParse(map['consumed_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
