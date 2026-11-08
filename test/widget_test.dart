import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fittrack_ai/theme/fit_theme.dart';
import 'package:fittrack_ai/screens/catalog/food_catalog_screen.dart';
import 'package:fittrack_ai/database/catalog_repository.dart';
import 'package:fittrack_ai/screens/catalog/food_portion_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fittrack_ai/database/open_food_facts_client.dart';
import 'package:fittrack_ai/models/food.dart';
import 'package:fittrack_ai/models/meal_food_entry.dart';

Food sample() => Food(
  id: 'test',
  name: 'Poulet',
  brand: '',
  category: FoodCategory.proteins,
  referencePortion: '100 g',
  unit: FoodUnit.gram,
  caloriesPer100: 165,
  proteinPer100: 31,
  carbohydratePer100: 0,
  fatPer100: 3.6,
  ownerId: null,
  barcode: null,
  isBuiltIn: true,
  nutritionIsComplete: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class MemoryCatalog extends CatalogRepository {
  @override
  Future<List<Food>> listFoods({
    required String userId,
    String search = '',
    FoodCategory? category,
  }) async => search.isEmpty || 'poulet'.contains(search.toLowerCase())
      ? [sample()]
      : [];
}

void main() {
  testWidgets(
    'empty favorites can scroll under an expanded header on a short screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = MemoryCatalog();
      addTearDown(repository.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: FitTheme.dark,
          home: FoodCatalogScreen(
            currentUserId: 'local',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favoris'));
      await tester.pumpAndSettle();
      tester
          .state<NestedScrollViewState>(find.byType(NestedScrollView))
          .outerController
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'catalog remains usable with keyboard on a small mobile viewport',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = MemoryCatalog();
      addTearDown(repository.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: FitTheme.dark,
          home: FoodCatalogScreen(
            currentUserId: 'local',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -240));
      await tester.pumpAndSettle();
      expect(find.text('Poulet'), findsOneWidget);
      await tester.drag(find.byType(NestedScrollView), const Offset(0, 240));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favoris'));
      await tester.pumpAndSettle();
      expect(find.text('Poulet'), findsNothing);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile portion editor recalculates and blocks invalid confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: FitTheme.dark,
          home: Scaffold(
            body: FoodPortionSheet(food: sample(), userId: 'local'),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '150');
      await tester.pump();
      expect(find.textContaining('248 kcal'), findsOneWidget);
      expect(find.text('46.5 g'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );

  test('150 g stores proportional nutrition independently in journal', () {
    final entry = MealFoodEntry.fromFood(
      food: sample(),
      userId: 'local',
      amount: 150,
      mealSlot: MealSlot.lunch,
    );
    expect(entry.calories, 247.5);
    expect(entry.proteinGrams, 46.5);
    expect(() => sample().nutritionFor(0), throwsArgumentError);
    expect(() => sample().nutritionFor(double.nan), throwsArgumentError);
  });
  test('serving energy is never used as energy per 100 g', () async {
    final client = OpenFoodFactsClient(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'status': 1,
            'product': {
              'product_name': 'Produit',
              'nutriments': {
                'energy-kcal_value': 90,
                'energy_100g': 1673.6,
                'proteins_100g': 10,
                'carbohydrates_100g': 50,
                'fat_100g': 10,
              },
            },
          }),
          200,
        ),
      ),
    );
    final food = await client.fetchFood('12345678');
    expect(food!.caloriesPer100, closeTo(400, 0.01));
  });
}
