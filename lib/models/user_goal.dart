class UserGoal {
  final String userId;
  final String goalType; // 'weight_loss', 'maintenance', 'weight_gain'
  final double targetWeightKg;
  final int dailyCalories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int dailyWaterMl;
  final bool isManual;

  const UserGoal({
    required this.userId,
    required this.goalType,
    required this.targetWeightKg,
    required this.dailyCalories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.dailyWaterMl,
    required this.isManual,
  });

  Map<String, dynamic> toDatabaseMap() {
    return {
      'user_id': userId,
      'goal_type': goalType,
      'target_weight_kg': targetWeightKg,
      'daily_calories': dailyCalories,
      'protein_grams': proteinGrams,
      'carbs_grams': carbsGrams,
      'fat_grams': fatGrams,
      'daily_water_ml': dailyWaterMl,
      'is_manual': isManual ? 1 : 0,
    };
  }

  factory UserGoal.fromDatabaseMap(Map<String, dynamic> map) {
    return UserGoal(
      userId: map['user_id'] as String,
      goalType: map['goal_type'] as String,
      targetWeightKg: (map['target_weight_kg'] as num).toDouble(),
      dailyCalories: (map['daily_calories'] as num).toInt(),
      proteinGrams: (map['protein_grams'] as num).toInt(),
      carbsGrams: (map['carbs_grams'] as num).toInt(),
      fatGrams: (map['fat_grams'] as num).toInt(),
      dailyWaterMl: (map['daily_water_ml'] as num).toInt(),
      isManual: (map['is_manual'] as int) == 1,
    );
  }

  UserGoal copyWith({
    String? goalType,
    double? targetWeightKg,
    int? dailyCalories,
    int? proteinGrams,
    int? carbsGrams,
    int? fatGrams,
    int? dailyWaterMl,
    bool? isManual,
  }) {
    return UserGoal(
      userId: userId,
      goalType: goalType ?? this.goalType,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      dailyCalories: dailyCalories ?? this.dailyCalories,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      dailyWaterMl: dailyWaterMl ?? this.dailyWaterMl,
      isManual: isManual ?? this.isManual,
    );
  }
}
