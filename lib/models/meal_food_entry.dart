import 'package:flutter/foundation.dart';

import 'food.dart';

enum MealSlot { breakfast, lunch, dinner, snack }

extension MealSlotLabel on MealSlot {
  String get label => switch (this) {
    MealSlot.breakfast => 'Petit-déjeuner',
    MealSlot.lunch => 'Déjeuner',
    MealSlot.dinner => 'Dîner',
    MealSlot.snack => 'Collation',
  };
}

@immutable
class MealFoodEntry {
  const MealFoodEntry({
    this.id,
    required this.userId,
    required this.foodName,
    required this.brand,
    required this.amount,
    required this.unit,
    required this.calories,
    required this.proteinGrams,
    required this.carbohydrateGrams,
    required this.fatGrams,
    required this.mealSlot,
    required this.consumedAt,
  });

  final int? id;
  final String userId;
  final String foodName;
  final String brand;
  final double amount;
  final FoodUnit unit;
  final double calories;
  final double proteinGrams;
  final double carbohydrateGrams;
  final double fatGrams;
  final MealSlot mealSlot;
  final DateTime consumedAt;

  /// Copies food values now; the journal row has no catalogue foreign key.
  factory MealFoodEntry.fromFood({
    required Food food,
    required String userId,
    required double amount,
    required MealSlot mealSlot,
    DateTime? consumedAt,
  }) {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Un utilisateur est requis.');
    }
    final nutrition = food.nutritionFor(amount);
    return MealFoodEntry(
      userId: userId,
      foodName: food.name,
      brand: food.brand,
      amount: amount,
      unit: food.unit,
      calories: nutrition.calories,
      proteinGrams: nutrition.proteinGrams,
      carbohydrateGrams: nutrition.carbohydrateGrams,
      fatGrams: nutrition.fatGrams,
      mealSlot: mealSlot,
      consumedAt: consumedAt ?? DateTime.now(),
    );
  }

  Map<String, Object?> toDatabaseMap() => {
    'user_id': userId,
    'food_name': foodName,
    'brand': brand,
    'amount': amount,
    'unit': unit.name,
    'calories': calories,
    'protein_grams': proteinGrams,
    'carbohydrate_grams': carbohydrateGrams,
    'fat_grams': fatGrams,
    'meal_slot': mealSlot.name,
    'consumed_at': consumedAt.toIso8601String(),
  };

  factory MealFoodEntry.fromDatabaseMap(Map<String, Object?> map) {
    double readDouble(String key) => (map[key] as num?)?.toDouble() ?? 0;

    return MealFoodEntry(
      id: (map['id'] as num?)?.toInt(),
      userId: map['user_id'] as String? ?? '',
      foodName: map['food_name'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      amount: readDouble('amount'),
      unit: FoodUnitLabel.fromStorage(map['unit'] as String?),
      calories: readDouble('calories'),
      proteinGrams: readDouble('protein_grams'),
      carbohydrateGrams: readDouble('carbohydrate_grams'),
      fatGrams: readDouble('fat_grams'),
      mealSlot: MealSlot.values.firstWhere(
        (slot) => slot.name == map['meal_slot'],
        orElse: () => MealSlot.snack,
      ),
      consumedAt:
          DateTime.tryParse(map['consumed_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
