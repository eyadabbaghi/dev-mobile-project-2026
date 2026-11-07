import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../models/food.dart';
import '../models/meal_food_entry.dart';
import 'app_database.dart';
import 'catalog_exception.dart';
import 'open_food_facts_client.dart';

class CatalogRepository {
  CatalogRepository({AppDatabase? database, http.Client? httpClient})
    : _database = database ?? AppDatabase.instance,
      _ownsClient = httpClient == null,
      _httpClient = httpClient ?? http.Client() {
    _openFoodFacts = OpenFoodFactsClient(_httpClient);
  }

  static final CatalogRepository instance = CatalogRepository();

  final AppDatabase _database;
  final http.Client _httpClient;
  final bool _ownsClient;
  late final OpenFoodFactsClient _openFoodFacts;

  Future<List<Food>> listFoods({
    required String userId,
    String search = '',
    FoodCategory? category,
  }) async {
    _requireUser(userId);
    try {
      final database = await _database.database;
      final clauses = <String>[];
      final arguments = <Object?>[userId];
      final normalizedSearch = search.trim().toLowerCase();
      if (normalizedSearch.isNotEmpty) {
        clauses.add('(lower(f.name) LIKE ? OR lower(f.brand) LIKE ?)');
        final value = '%$normalizedSearch%';
        arguments
          ..add(value)
          ..add(value);
      }
      if (category != null) {
        clauses.add('f.category = ?');
        arguments.add(category.name);
      }
      final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
      final rows = await database.rawQuery('''
        SELECT f.*,
          CASE WHEN favorite.food_id IS NULL THEN 0 ELSE 1 END AS is_favorite
        FROM foods AS f
        LEFT JOIN food_favorites AS favorite
          ON favorite.food_id = f.id AND favorite.user_id = ?
        $where
        ORDER BY CASE WHEN favorite.food_id IS NULL THEN 1 ELSE 0 END ASC,
          f.name COLLATE NOCASE ASC
      ''', arguments);
      return rows.map(Food.fromDatabaseMap).toList(growable: false);
    } on CatalogException {
      rethrow;
    } on Exception catch (error) {
      throw CatalogException(
        'Impossible de charger le catalogue.',
        cause: error,
      );
    }
  }

  Future<Food?> getFood(String id, {required String userId}) async {
    _requireUser(userId);
    try {
      final database = await _database.database;
      final rows = await database.rawQuery(
        '''
        SELECT f.*, CASE WHEN favorite.food_id IS NULL THEN 0 ELSE 1 END AS is_favorite
        FROM foods AS f
        LEFT JOIN food_favorites AS favorite
          ON favorite.food_id = f.id AND favorite.user_id = ?
        WHERE f.id = ?
        LIMIT 1
      ''',
        [userId, id],
      );
      return rows.isEmpty ? null : Food.fromDatabaseMap(rows.first);
    } on CatalogException {
      rethrow;
    } on Exception catch (error) {
      throw CatalogException(
        'Impossible de charger cette fiche alimentaire.',
        cause: error,
      );
    }
  }

  Future<Food?> findLocalByBarcode(String barcode) async {
    final normalized = normalizeBarcode(barcode);
    try {
      final database = await _database.database;
      final rows = await database.query(
        'foods',
        where: 'barcode = ?',
        whereArgs: [normalized],
        limit: 1,
      );
      return rows.isEmpty ? null : Food.fromDatabaseMap(rows.first);
    } on CatalogException {
      rethrow;
    } on Exception catch (error) {
      throw CatalogException(
        'Impossible de consulter le code-barres local.',
        cause: error,
      );
    }
  }

  Future<Food?> findByBarcode(String barcode, {required String userId}) async {
    _requireUser(userId);
    final normalized = normalizeBarcode(barcode);
    final cached = await findLocalByBarcode(normalized);
    if (cached != null) return getFood(cached.id!, userId: userId);

    final product = await _openFoodFacts.fetchFood(normalized);
    if (product == null) return null;
    final saved = await _cacheScannedFood(product);
    return getFood(saved.id!, userId: userId);
  }

  Future<Food> savePersonalFood(Food food, {required String userId}) async {
    _requireUser(userId);
    _validateFood(food);
    final barcode = food.barcode?.trim();
    final normalizedFood = food.copyWith(
      barcode: barcode == null || barcode.isEmpty ? null : barcode,
      clearBarcode: barcode == null || barcode.isEmpty,
    );

    try {
      final database = await _database.database;
      return await database.transaction((transaction) async {
        final now = DateTime.now();
        if (normalizedFood.id == null) {
          final created = normalizedFood.copyWith(
            id: _newId(),
            ownerId: userId,
            isBuiltIn: false,
            isFavorite: false,
            createdAt: now,
            updatedAt: now,
          );
          await transaction.insert('foods', created.toDatabaseMap());
          return created;
        }

        final existing = await transaction.query(
          'foods',
          columns: ['owner_id'],
          where: 'id = ?',
          whereArgs: [normalizedFood.id],
          limit: 1,
        );
        if (existing.isEmpty || existing.first['owner_id'] != userId) {
          throw const CatalogException(
            'Vous ne pouvez modifier que vos propres fiches.',
          );
        }

        final updated = normalizedFood.copyWith(
          ownerId: userId,
          isBuiltIn: false,
          isFavorite: false,
          updatedAt: now,
        );
        await transaction.update(
          'foods',
          updated.toDatabaseMap(),
          where: 'id = ? AND owner_id = ?',
          whereArgs: [normalizedFood.id, userId],
        );
        return updated;
      });
    } on CatalogException {
      rethrow;
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw CatalogException(
          'Ce code-barres est déjà associé à une fiche.',
          cause: error,
        );
      }
      throw CatalogException(
        'Impossible d’enregistrer cette fiche alimentaire.',
        cause: error,
      );
    } on Exception catch (error) {
      throw CatalogException(
        'Impossible d’enregistrer cette fiche alimentaire.',
        cause: error,
      );
    }
  }

  Future<void> deletePersonalFood(String id, {required String userId}) async {
    _requireUser(userId);
    try {
      final database = await _database.database;
      final deleted = await database.delete(
        'foods',
        where: 'id = ? AND owner_id = ?',
        whereArgs: [id, userId],
      );
      if (deleted == 0) {
        throw const CatalogException(
          'Vous ne pouvez supprimer que vos propres fiches.',
        );
      }
    } on CatalogException {
      rethrow;
    } on Exception catch (error) {
      throw CatalogException(
        'Impossible de supprimer cette fiche alimentaire.',
        cause: error,
      );
    }
  }

  Future<bool> toggleFavorite(String foodId, {required String userId}) async {
    _requireUser(userId);
    try {
      final database = await _database.database;
      return await database.transaction((transaction) async {
        final exists = await transaction.query(
          'foods',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [foodId],
          limit: 1,
        );
        if (exists.isEmpty) {
          throw const CatalogException(
            'Cette fiche alimentaire n’existe plus.',
          );
        }
        final favorite = await transaction.query(
          'food_favorites',
          columns: ['food_id'],
          where: 'user_id = ? AND food_id = ?',
          whereArgs: [userId, foodId],
          limit: 1,
        );
        if (favorite.isNotEmpty) {
          await transaction.delete(
            'food_favorites',
            where: 'user_id = ? AND food_id = ?',
            whereArgs: [userId, foodId],
          );
          return false;
        }
        await transaction.insert('food_favorites', {
          'user_id': userId,
          'food_id': foodId,
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      });
    } on CatalogException {
      rethrow;
    } on Exception catch (error) {
      throw CatalogException(
        'Impossible de mettre à jour vos favoris.',
        cause: error,
      );
    }
  }

  Future<int> addJournalEntry(MealFoodEntry entry) async {
    if (entry.userId.trim().isEmpty) {
      throw const CatalogException(
        'Un utilisateur est requis pour enregistrer un repas.',
      );
    }
    if (!entry.amount.isFinite || entry.amount <= 0) {
      throw const CatalogException(
        'La quantité doit être strictement positive.',
      );
    }
    try {
      final database = await _database.database;
      return await database.insert('meal_food_entries', entry.toDatabaseMap());
    } on Exception catch (error) {
      throw CatalogException(
        'Impossible d’ajouter cet aliment au journal.',
        cause: error,
      );
    }
  }

  Future<List<MealFoodEntry>> listJournalEntries({
    required String userId,
    DateTime? date,
  }) async {
    _requireUser(userId);
    try {
      final database = await _database.database;
      final clauses = <String>['user_id = ?'];
      final arguments = <Object?>[userId];
      if (date != null) {
        final day = DateTime(date.year, date.month, date.day);
        final nextDay = day.add(const Duration(days: 1));
        clauses.add('consumed_at >= ? AND consumed_at < ?');
        arguments
          ..add(day.toIso8601String())
          ..add(nextDay.toIso8601String());
      }
      final rows = await database.query(
        'meal_food_entries',
        where: clauses.join(' AND '),
        whereArgs: arguments,
        orderBy: 'consumed_at ASC, id ASC',
      );
      return rows.map(MealFoodEntry.fromDatabaseMap).toList(growable: false);
    } on Exception catch (error) {
      throw CatalogException(
        'Impossible de charger les entrées du journal.',
        cause: error,
      );
    }
  }

  Future<Food> _cacheScannedFood(Food product) async {
    final database = await _database.database;
    try {
      return await database.transaction((transaction) async {
        final existing = await transaction.query(
          'foods',
          where: 'barcode = ?',
          whereArgs: [product.barcode],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          final cached = Food.fromDatabaseMap(existing.first);
          if (cached.isPersonal) return cached;
          final refreshed = product.copyWith(
            id: cached.id,
            createdAt: cached.createdAt,
            updatedAt: DateTime.now(),
          );
          await transaction.update(
            'foods',
            refreshed.toDatabaseMap(),
            where: 'id = ? AND owner_id IS NULL',
            whereArgs: [cached.id],
          );
          return refreshed;
        }
        await transaction.insert('foods', product.toDatabaseMap());
        return product;
      });
    } on Exception catch (error) {
      throw CatalogException(
        'Le produit a été trouvé, mais sa mise en cache a échoué.',
        cause: error,
      );
    }
  }

  static String normalizeBarcode(String value) {
    final normalized = value.trim();
    if (!RegExp(r'^\d{8,14}$').hasMatch(normalized)) {
      throw const CatalogException(
        'Le code-barres doit contenir entre 8 et 14 chiffres.',
      );
    }
    return normalized;
  }

  static void _validateFood(Food food) {
    if (food.name.trim().isEmpty) {
      throw const CatalogException('Le nom du produit est obligatoire.');
    }
    if (food.referencePortion.trim().isEmpty) {
      throw const CatalogException('La portion de référence est obligatoire.');
    }
    for (final value in [
      food.caloriesPer100,
      food.proteinPer100,
      food.carbohydratePer100,
      food.fatPer100,
    ]) {
      if (!value.isFinite || value < 0) {
        throw const CatalogException(
          'Les valeurs nutritionnelles doivent être positives ou nulles.',
        );
      }
    }
    final barcode = food.barcode?.trim();
    if (barcode != null && barcode.isNotEmpty) normalizeBarcode(barcode);
  }

  static void _requireUser(String userId) {
    if (userId.trim().isEmpty) {
      throw const CatalogException(
        'Aucun utilisateur connecté n’a été fourni.',
      );
    }
  }

  static String _newId() {
    final randomSuffix = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return 'food-${DateTime.now().microsecondsSinceEpoch}-$randomSuffix';
  }

  void close() {
    if (_ownsClient) _httpClient.close();
  }
}
