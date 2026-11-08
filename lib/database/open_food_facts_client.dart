import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/food.dart';
import 'catalog_exception.dart';

class OpenFoodFactsClient {
  OpenFoodFactsClient(this._client);

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 10);
  static const String _userAgent =
      'FitTrackAI-Mobile/1.0 (nutrition barcode lookup)';

  Future<Food?> fetchFood(String barcode) async {
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/${Uri.encodeComponent(barcode)}.json',
      {
        'fields':
            'code,product_name,product_name_fr,brands,quantity,'
            'categories_tags,pnns_groups_1,nutriments',
      },
    );

    late http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': _userAgent,
            },
          )
          .timeout(_timeout);
    } on Exception catch (error) {
      throw CatalogException(
        'Catalogue en ligne indisponible. Vérifiez votre connexion et réessayez.',
        cause: error,
      );
    }

    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CatalogException(
        'Le service de produits a répondu avec le code ${response.statusCode}.',
      );
    }

    late Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Réponse JSON inattendue.');
      }
      payload = decoded;
    } on FormatException catch (error) {
      throw CatalogException(
        'Réponse invalide du catalogue en ligne.',
        cause: error,
      );
    }

    if (payload['status'] != 1) return null;
    final product = payload['product'];
    if (product is! Map<String, dynamic>) return null;

    final name = _firstNonEmpty([
      product['product_name_fr'],
      product['product_name'],
    ]);
    if (name == null) return null;

    final brand = _firstNonEmpty([product['brands']]) ?? '';
    final nutriments = product['nutriments'];
    if (nutriments is! Map<String, dynamic>) {
      throw const CatalogException(
        'Ce produit ne contient pas de données nutritionnelles.',
      );
    }

    final energy =
        _readNumber(nutriments['energy-kcal_100g']) ??
        _toKcal(_readNumber(nutriments['energy_100g']));
    final protein = _readNumber(nutriments['proteins_100g']);
    final carbohydrate = _readNumber(nutriments['carbohydrates_100g']);
    final fat = _readNumber(nutriments['fat_100g']);
    if (energy == null &&
        protein == null &&
        carbohydrate == null &&
        fat == null) {
      throw const CatalogException(
        'Les valeurs nutritionnelles de ce produit sont indisponibles.',
      );
    }

    final categories = <String>[
      if (product['pnns_groups_1'] is String)
        product['pnns_groups_1'] as String,
      if (product['categories_tags'] is List)
        ...(product['categories_tags'] as List).whereType<String>(),
    ].join(' ').toLowerCase();
    final isLiquid =
        categories.contains('beverage') ||
        categories.contains('drink') ||
        categories.contains('boisson');
    final unit = isLiquid ? FoodUnit.milliliter : FoodUnit.gram;
    final quantity =
        _firstNonEmpty([product['quantity']]) ?? '100 ${unit.symbol}';
    final now = DateTime.now();

    return Food(
      id: 'off-$barcode',
      name: name,
      brand: brand,
      category: _categoryFromText(categories),
      referencePortion: quantity,
      unit: unit,
      caloriesPer100: energy ?? 0,
      proteinPer100: protein ?? 0,
      carbohydratePer100: carbohydrate ?? 0,
      fatPer100: fat ?? 0,
      ownerId: null,
      barcode: barcode,
      isBuiltIn: false,
      nutritionIsComplete:
          energy != null &&
          protein != null &&
          carbohydrate != null &&
          fat != null,
      createdAt: now,
      updatedAt: now,
    );
  }

  static String? _firstNonEmpty(Iterable<Object?> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static double? _readNumber(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static double? _toKcal(double? kilojoules) =>
      kilojoules == null ? null : kilojoules / 4.184;

  static FoodCategory _categoryFromText(String text) {
    if (text.contains('fruit') ||
        text.contains('vegetable') ||
        text.contains('légume')) {
      return FoodCategory.fruitsVegetables;
    }
    if (text.contains('cereal') ||
        text.contains('grain') ||
        text.contains('céréale')) {
      return FoodCategory.cereals;
    }
    if (text.contains('dairy') ||
        text.contains('milk') ||
        text.contains('laitier')) {
      return FoodCategory.dairy;
    }
    if (text.contains('beverage') ||
        text.contains('drink') ||
        text.contains('boisson')) {
      return FoodCategory.beverages;
    }
    if (text.contains('oil') ||
        text.contains('fat') ||
        text.contains('huile')) {
      return FoodCategory.fats;
    }
    if (text.contains('meat') ||
        text.contains('fish') ||
        text.contains('protein') ||
        text.contains('viande') ||
        text.contains('poisson')) {
      return FoodCategory.proteins;
    }
    if (text.contains('snack') ||
        text.contains('sweet') ||
        text.contains('dessert')) {
      return FoodCategory.snacks;
    }
    return FoodCategory.other;
  }
}
