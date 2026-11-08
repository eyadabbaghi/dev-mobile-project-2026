import 'package:flutter/foundation.dart';

import 'food.dart';
import 'meal_food_entry.dart';

@immutable
class MealTemplateItem {
  const MealTemplateItem({
    this.id,
    this.templateId,
    required this.foodName,
    required this.brand,
    required this.amount,
    required this.unit,
    required this.calories,
    required this.proteinGrams,
    required this.carbohydrateGrams,
    required this.fatGrams,
  });

  final int? id;
  final int? templateId;
  final String foodName;
  final String brand;
  final double amount;
  final FoodUnit unit;
  final double calories;
  final double proteinGrams;
  final double carbohydrateGrams;
  final double fatGrams;

  Map<String, Object?> toDatabaseMap([int? explicitTemplateId]) => {
    if (id != null) 'id': id,
    'template_id': explicitTemplateId ?? templateId,
    'food_name': foodName,
    'brand': brand,
    'amount': amount,
    'unit': unit.name,
    'calories': calories,
    'protein_grams': proteinGrams,
    'carbohydrate_grams': carbohydrateGrams,
    'fat_grams': fatGrams,
  };

  factory MealTemplateItem.fromDatabaseMap(Map<String, Object?> map) {
    double readDouble(String key) => (map[key] as num?)?.toDouble() ?? 0;

    return MealTemplateItem(
      id: (map['id'] as num?)?.toInt(),
      templateId: (map['template_id'] as num?)?.toInt(),
      foodName: map['food_name'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      amount: readDouble('amount'),
      unit: FoodUnitLabel.fromStorage(map['unit'] as String?),
      calories: readDouble('calories'),
      proteinGrams: readDouble('protein_grams'),
      carbohydrateGrams: readDouble('carbohydrate_grams'),
      fatGrams: readDouble('fat_grams'),
    );
  }

  factory MealTemplateItem.fromMealFoodEntry(MealFoodEntry entry) {
    return MealTemplateItem(
      foodName: entry.foodName,
      brand: entry.brand,
      amount: entry.amount,
      unit: entry.unit,
      calories: entry.calories,
      proteinGrams: entry.proteinGrams,
      carbohydrateGrams: entry.carbohydrateGrams,
      fatGrams: entry.fatGrams,
    );
  }

  MealFoodEntry toMealFoodEntry({
    required String userId,
    required MealSlot mealSlot,
    required DateTime consumedAt,
  }) {
    return MealFoodEntry(
      userId: userId,
      foodName: foodName,
      brand: brand,
      amount: amount,
      unit: unit,
      calories: calories,
      proteinGrams: proteinGrams,
      carbohydrateGrams: carbohydrateGrams,
      fatGrams: fatGrams,
      mealSlot: mealSlot,
      consumedAt: consumedAt,
    );
  }
}

@immutable
class MealTemplate {
  const MealTemplate({
    this.id,
    required this.userId,
    required this.name,
    required this.mealSlot,
    required this.createdAt,
    this.items = const [],
  });

  final int? id;
  final String userId;
  final String name;
  final MealSlot mealSlot;
  final DateTime createdAt;
  final List<MealTemplateItem> items;

  double get totalCalories =>
      items.fold(0, (sum, item) => sum + item.calories);

  Map<String, Object?> toDatabaseMap() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'name': name,
    'meal_slot': mealSlot.name,
    'created_at': createdAt.toIso8601String(),
  };

  factory MealTemplate.fromDatabaseMap(
    Map<String, Object?> map, [
    List<MealTemplateItem> items = const [],
  ]) {
    return MealTemplate(
      id: (map['id'] as num?)?.toInt(),
      userId: map['user_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      mealSlot: MealSlot.values.firstWhere(
        (slot) => slot.name == map['meal_slot'],
        orElse: () => MealSlot.snack,
      ),
      createdAt:
          DateTime.tryParse(map['consumed_at'] as String? ?? '') ??
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      items: items,
    );
  }
}
