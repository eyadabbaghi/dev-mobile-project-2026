import 'package:flutter/foundation.dart';

enum FoodCategory {
  fruitsVegetables,
  cereals,
  proteins,
  dairy,
  fats,
  beverages,
  snacks,
  other,
}

extension FoodCategoryLabel on FoodCategory {
  String get label => switch (this) {
    FoodCategory.fruitsVegetables => 'Fruits & légumes',
    FoodCategory.cereals => 'Céréales',
    FoodCategory.proteins => 'Protéines',
    FoodCategory.dairy => 'Produits laitiers',
    FoodCategory.fats => 'Matières grasses',
    FoodCategory.beverages => 'Boissons',
    FoodCategory.snacks => 'Snacks',
    FoodCategory.other => 'Autres',
  };

  static FoodCategory fromStorage(String? value) =>
      FoodCategory.values.firstWhere(
        (category) => category.name == value,
        orElse: () => FoodCategory.other,
      );
}

enum FoodUnit { gram, milliliter }

extension FoodUnitLabel on FoodUnit {
  String get symbol => this == FoodUnit.gram ? 'g' : 'ml';
  String get nameForScreen =>
      this == FoodUnit.gram ? 'Grammes (g)' : 'Millilitres (ml)';

  static FoodUnit fromStorage(String? value) =>
      value == FoodUnit.milliliter.name ? FoodUnit.milliliter : FoodUnit.gram;
}

@immutable
class NutritionFacts {
  const NutritionFacts({
    required this.calories,
    required this.proteinGrams,
    required this.carbohydrateGrams,
    required this.fatGrams,
  });

  final double calories;
  final double proteinGrams;
  final double carbohydrateGrams;
  final double fatGrams;

  factory NutritionFacts.forAmount(Food food, double amount) {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'La quantité doit être strictement positive.',
      );
    }
    final factor = amount / 100;
    return NutritionFacts(
      calories: food.caloriesPer100 * factor,
      proteinGrams: food.proteinPer100 * factor,
      carbohydrateGrams: food.carbohydratePer100 * factor,
      fatGrams: food.fatPer100 * factor,
    );
  }
}

@immutable
class Food {
  const Food({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.referencePortion,
    required this.unit,
    required this.caloriesPer100,
    required this.proteinPer100,
    required this.carbohydratePer100,
    required this.fatPer100,
    required this.ownerId,
    required this.barcode,
    required this.isBuiltIn,
    required this.nutritionIsComplete,
    required this.createdAt,
    required this.updatedAt,
    this.isFavorite = false,
  });

  final String? id;
  final String name;
  final String brand;
  final FoodCategory category;
  final String referencePortion;
  final FoodUnit unit;
  final double caloriesPer100;
  final double proteinPer100;
  final double carbohydratePer100;
  final double fatPer100;
  final String? ownerId;
  final String? barcode;
  final bool isBuiltIn;
  final bool nutritionIsComplete;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;

  bool get isPersonal => ownerId != null;
  NutritionFacts nutritionFor(double amount) =>
      NutritionFacts.forAmount(this, amount);

  Food copyWith({
    String? id,
    String? name,
    String? brand,
    FoodCategory? category,
    String? referencePortion,
    FoodUnit? unit,
    double? caloriesPer100,
    double? proteinPer100,
    double? carbohydratePer100,
    double? fatPer100,
    String? ownerId,
    String? barcode,
    bool clearBarcode = false,
    bool? isBuiltIn,
    bool? nutritionIsComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
  }) => Food(
    id: id ?? this.id,
    name: name ?? this.name,
    brand: brand ?? this.brand,
    category: category ?? this.category,
    referencePortion: referencePortion ?? this.referencePortion,
    unit: unit ?? this.unit,
    caloriesPer100: caloriesPer100 ?? this.caloriesPer100,
    proteinPer100: proteinPer100 ?? this.proteinPer100,
    carbohydratePer100: carbohydratePer100 ?? this.carbohydratePer100,
    fatPer100: fatPer100 ?? this.fatPer100,
    ownerId: ownerId ?? this.ownerId,
    barcode: clearBarcode ? null : barcode ?? this.barcode,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    nutritionIsComplete: nutritionIsComplete ?? this.nutritionIsComplete,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  Map<String, Object?> toDatabaseMap() => {
    'id': id,
    'name': name.trim(),
    'brand': brand.trim(),
    'category': category.name,
    'reference_portion': referencePortion.trim(),
    'unit': unit.name,
    'calories_per_100': caloriesPer100,
    'protein_per_100': proteinPer100,
    'carbohydrate_per_100': carbohydratePer100,
    'fat_per_100': fatPer100,
    'owner_id': ownerId,
    'barcode': barcode,
    'is_builtin': isBuiltIn ? 1 : 0,
    'nutrition_is_complete': nutritionIsComplete ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Food.fromDatabaseMap(Map<String, Object?> map) {
    double readDouble(String key) => (map[key] as num?)?.toDouble() ?? 0;

    return Food(
      id: map['id'] as String?,
      name: map['name'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      category: FoodCategoryLabel.fromStorage(map['category'] as String?),
      referencePortion: map['reference_portion'] as String? ?? '100 g',
      unit: FoodUnitLabel.fromStorage(map['unit'] as String?),
      caloriesPer100: readDouble('calories_per_100'),
      proteinPer100: readDouble('protein_per_100'),
      carbohydratePer100: readDouble('carbohydrate_per_100'),
      fatPer100: readDouble('fat_per_100'),
      ownerId: map['owner_id'] as String?,
      barcode: map['barcode'] as String?,
      isBuiltIn: (map['is_builtin'] as num?)?.toInt() == 1,
      nutritionIsComplete: (map['nutrition_is_complete'] as num?)?.toInt() != 0,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
      isFavorite: (map['is_favorite'] as num?)?.toInt() == 1,
    );
  }
}
