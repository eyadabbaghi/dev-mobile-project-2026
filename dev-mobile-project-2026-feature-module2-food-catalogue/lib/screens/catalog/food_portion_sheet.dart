import 'package:flutter/material.dart';

import 'nutrition_summary.dart';

import 'package:flutter/services.dart';

import '../../models/food.dart';
import '../../models/meal_food_entry.dart';

class FoodPortionSheet extends StatefulWidget {
  const FoodPortionSheet({super.key, required this.food, required this.userId});

  final Food food;
  final String userId;

  static Future<MealFoodEntry?> show(
    BuildContext context, {
    required Food food,
    required String userId,
  }) {
    return showModalBottomSheet<MealFoodEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FoodPortionSheet(food: food, userId: userId),
    );
  }

  @override
  State<FoodPortionSheet> createState() => _FoodPortionSheetState();
}

class _FoodPortionSheetState extends State<FoodPortionSheet> {
  final _amountController = TextEditingController(text: '100');
  MealSlot _mealSlot = MealSlot.lunch;

  double? get _amount {
    final value = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    if (value == null || !value.isFinite || value <= 0) return null;
    return value;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = _amount;
    final nutrition = amount == null ? null : widget.food.nutritionFor(amount);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ajouter au journal',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              widget.food.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              autofocus: false,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,3}')),
              ],
              decoration: InputDecoration(
                labelText: 'Quantité',
                suffixText: widget.food.unit.symbol,
                helperText:
                    'Les valeurs sont calculées pour 100 ${widget.food.unit.symbol}.',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final preset in [50, 100, 150, 200])
                  ActionChip(
                    label: Text('$preset ${widget.food.unit.symbol}'),
                    onPressed: () {
                      _amountController.text = '$preset';
                      setState(() {});
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MealSlot>(
              initialValue: _mealSlot,
              decoration: const InputDecoration(
                labelText: 'Créneau repas',
                border: OutlineInputBorder(),
              ),
              items: MealSlot.values
                  .map(
                    (slot) =>
                        DropdownMenuItem(value: slot, child: Text(slot.label)),
                  )
                  .toList(),
              onChanged: (slot) {
                if (slot != null) setState(() => _mealSlot = slot);
              },
            ),
            const SizedBox(height: 20),
            if (nutrition != null) NutritionSummary(nutrition: nutrition),
            if (nutrition == null)
              const Text(
                'Saisissez une quantité supérieure à zéro pour voir le calcul.',
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: amount == null ? null : () => _add(amount),
                icon: const Icon(Icons.playlist_add),
                label: Text(
                  nutrition == null
                      ? 'Ajouter au repas'
                      : 'Ajouter au repas · ${nutrition.calories.toStringAsFixed(0)} kcal',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _add(double amount) {
    try {
      final entry = MealFoodEntry.fromFood(
        food: widget.food,
        userId: widget.userId,
        amount: amount,
        mealSlot: _mealSlot,
      );
      Navigator.of(context).pop(entry);
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message?.toString() ?? 'Quantité invalide.'),
        ),
      );
    }
  }
}
