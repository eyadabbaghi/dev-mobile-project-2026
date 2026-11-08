import 'package:flutter/material.dart';

import '../../../database/catalog_repository.dart';
import '../../../models/food.dart';
import '../../../models/meal_food_entry.dart';
import '../../../theme/fit_theme.dart';

class AddMealFoodSheet extends StatefulWidget {
  const AddMealFoodSheet({
    super.key,
    required this.userId,
    required this.mealSlot,
    required this.onFoodAdded,
  });

  final String userId;
  final MealSlot mealSlot;
  final ValueChanged<MealFoodEntry> onFoodAdded;

  @override
  State<AddMealFoodSheet> createState() => _AddMealFoodSheetState();
}

class _AddMealFoodSheetState extends State<AddMealFoodSheet> {
  final CatalogRepository _catalogRepo = CatalogRepository.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Food> _foods = [];
  bool _isLoading = true;
  FoodCategory? _selectedCategory;
  Food? _selectedFood;
  double _amount = 100.0;

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFoods() async {
    setState(() => _isLoading = true);
    try {
      final list = await _catalogRepo.listFoods(
        userId: widget.userId,
        search: _searchController.text,
        category: _selectedCategory,
      );
      if (mounted) {
        setState(() {
          _foods = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _submitEntry() {
    final food = _selectedFood;
    if (food == null || _amount <= 0) return;

    final entry = MealFoodEntry.fromFood(
      food: food,
      userId: widget.userId,
      amount: _amount,
      mealSlot: widget.mealSlot,
      consumedAt: DateTime.now(),
    );

    widget.onFoodAdded(entry);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ajouter à ${widget.mealSlot.label}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: FitTheme.muted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barre de recherche
          SearchBar(
            controller: _searchController,
            hintText: 'Rechercher un aliment...',
            leading: const Icon(Icons.search, color: FitTheme.muted),
            onChanged: (_) => _loadFoods(),
          ),
          const SizedBox(height: 12),
          // Filtre par catégorie
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Tous'),
                  selected: _selectedCategory == null,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = null);
                      _loadFoods();
                    }
                  },
                ),
                const SizedBox(width: 8),
                ...FoodCategory.values.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(cat.label),
                      selected: _selectedCategory == cat,
                      onSelected: (selected) {
                        setState(() => _selectedCategory = selected ? cat : null);
                        _loadFoods();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Liste des aliments ou calculateur
          Expanded(
            child: _selectedFood != null
                ? _buildPortionCalculator(theme)
                : _buildFoodList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: FitTheme.lime));
    }

    if (_foods.isEmpty) {
      return const Center(
        child: Text(
          'Aucun aliment trouvé.',
          style: TextStyle(color: FitTheme.muted),
        ),
      );
    }

    return ListView.builder(
      itemCount: _foods.length,
      itemBuilder: (ctx, index) {
        final food = _foods[index];
        final nutrition = food.nutritionFor(100);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              food.name,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            subtitle: Text(
              '${food.brand.isNotEmpty ? "${food.brand} • " : ""}${nutrition.calories.round()} kcal / 100${food.unit == FoodUnit.gram ? "g" : "ml"}',
              style: const TextStyle(color: FitTheme.muted, fontSize: 13),
            ),
            trailing: food.isFavorite
                ? const Icon(Icons.star, color: FitTheme.lime, size: 20)
                : const Icon(Icons.add_circle_outline, color: FitTheme.lime),
            onTap: () {
              setState(() {
                _selectedFood = food;
                _amount = 100.0;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildPortionCalculator(ThemeData theme) {
    final food = _selectedFood!;
    final nutrition = food.nutritionFor(_amount);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _selectedFood = null),
              ),
              Expanded(
                child: Text(
                  food.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Saisie de la portion
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Quantité consommé (${food.unit == FoodUnit.gram ? "Grammes" : "Millilitres"})',
                    style: const TextStyle(color: FitTheme.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_amount.round()} ${food.unit == FoodUnit.gram ? "g" : "ml"}',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: FitTheme.lime),
                  ),
                  Slider(
                    value: _amount.clamp(10, 500),
                    min: 10,
                    max: 500,
                    divisions: 98,
                    activeColor: FitTheme.lime,
                    inactiveColor: FitTheme.border,
                    onChanged: (val) => setState(() => _amount = val),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [50, 100, 150, 200, 250].map((preset) {
                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        onPressed: () => setState(() => _amount = preset.toDouble()),
                        child: Text('${preset}g'),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Récapitulatif Nutritionnel
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Valeurs nutritionnelles calculées',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMacroStat('Calories', '${nutrition.calories.round()} kcal', FitTheme.lime),
                      _buildMacroStat('Protéines', '${nutrition.proteinGrams.toStringAsFixed(1)}g', Colors.orangeAccent),
                      _buildMacroStat('Glucides', '${nutrition.carbohydrateGrams.toStringAsFixed(1)}g', Colors.lightBlueAccent),
                      _buildMacroStat('Lipides', '${nutrition.fatGrams.toStringAsFixed(1)}g', Colors.redAccent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submitEntry,
            icon: const Icon(Icons.check),
            label: const Text('Ajouter au repas'),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: FitTheme.muted, fontSize: 12)),
      ],
    );
  }
}
