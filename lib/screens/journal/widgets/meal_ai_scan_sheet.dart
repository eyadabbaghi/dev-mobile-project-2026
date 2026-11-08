import 'dart:io';

import 'package:flutter/material.dart';

import '../../../models/food.dart';
import '../../../models/meal_food_entry.dart';
import '../../../services/ai/meal_ai_vision_service.dart';
import '../../../theme/fit_theme.dart';

class MealAiScanSheet extends StatefulWidget {
  const MealAiScanSheet({
    super.key,
    required this.imageFile,
    required this.userId,
    required this.mealSlot,
    required this.onEntriesConfirmed,
  });

  final File imageFile;
  final String userId;
  final MealSlot mealSlot;
  final ValueChanged<List<MealFoodEntry>> onEntriesConfirmed;

  @override
  State<MealAiScanSheet> createState() => _MealAiScanSheetState();
}

class _MealAiScanSheetState extends State<MealAiScanSheet> {
  final MealAiVisionService _visionService = MealAiVisionService();

  bool _isAnalyzing = true;
  List<MealFoodEntry> _detectedEntries = [];

  @override
  void initState() {
    super.initState();
    _analyzePhoto();
  }

  Future<void> _analyzePhoto() async {
    setState(() => _isAnalyzing = true);
    try {
      final results = await _visionService.analyzeMealPhoto(
        imageFile: widget.imageFile,
        userId: widget.userId,
        mealSlot: widget.mealSlot,
      );
      if (mounted) {
        setState(() {
          _detectedEntries = results;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _confirmAndSave() {
    if (_detectedEntries.isEmpty) return;
    widget.onEntriesConfirmed(_detectedEntries);
    Navigator.of(context).pop();
  }

  void _updateAmount(int index, double newAmount) {
    if (newAmount <= 0) return;
    setState(() {
      final item = _detectedEntries[index];
      final ratio = newAmount / (item.amount > 0 ? item.amount : 1.0);
      _detectedEntries[index] = MealFoodEntry(
        id: item.id,
        userId: item.userId,
        foodName: item.foodName,
        brand: item.brand,
        amount: newAmount,
        unit: item.unit,
        calories: (item.calories * ratio),
        proteinGrams: (item.proteinGrams * ratio),
        carbohydrateGrams: (item.carbohydrateGrams * ratio),
        fatGrams: (item.fatGrams * ratio),
        mealSlot: item.mealSlot,
        consumedAt: item.consumedAt,
      );
    });
  }

  void _removeEntry(int index) {
    setState(() {
      _detectedEntries.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: FitTheme.lime),
                  SizedBox(width: 8),
                  Text(
                    'Analyse IA de l\'assiette',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: FitTheme.muted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Aperçu Image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: Image.file(
                widget.imageFile,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isAnalyzing)
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: FitTheme.lime),
                  SizedBox(height: 16),
                  Text(
                    'Détection des aliments et estimation des portions par IA...',
                    style: TextStyle(color: FitTheme.muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            const Text(
              'Aliments détectés (Ajustez les portions si besoin) :',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _detectedEntries.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun aliment détecté sur cette photo.',
                        style: TextStyle(color: FitTheme.muted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _detectedEntries.length,
                      itemBuilder: (ctx, index) {
                        final item = _detectedEntries[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.foodName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.calories.round()} kcal • Prot: ${item.proteinGrams.toStringAsFixed(1)}g',
                                        style: const TextStyle(
                                          color: FitTheme.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: FitTheme.muted, size: 20),
                                      onPressed: () => _updateAmount(index, item.amount - 20),
                                    ),
                                    Text(
                                      '${item.amount.round()} ${item.unit == FoodUnit.gram ? "g" : "ml"}',
                                      style: const TextStyle(
                                        color: FitTheme.lime,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: FitTheme.lime, size: 20),
                                      onPressed: () => _updateAmount(index, item.amount + 20),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      onPressed: () => _removeEntry(index),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _detectedEntries.isNotEmpty ? _confirmAndSave : null,
              icon: const Icon(Icons.check_circle),
              label: Text('Valider et ajouter (${_detectedEntries.length} aliments)'),
            ),
          ],
        ],
      ),
    );
  }
}
