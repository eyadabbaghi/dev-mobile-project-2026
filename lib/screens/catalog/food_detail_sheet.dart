import 'package:flutter/material.dart';

import 'nutrition_summary.dart';

import '../../database/catalog_exception.dart';
import '../../database/catalog_repository.dart';
import '../../models/food.dart';

class FoodDetailSheet extends StatefulWidget {
  const FoodDetailSheet({
    super.key,
    required this.food,
    required this.userId,
    required this.repository,
    required this.onChanged,
    required this.onEdit,
    required this.onAddToJournal,
  });

  final Food food;
  final String userId;
  final CatalogRepository repository;
  final VoidCallback onChanged;
  final ValueChanged<Food> onEdit;
  final Future<void> Function(Food) onAddToJournal;

  @override
  State<FoodDetailSheet> createState() => _FoodDetailSheetState();
}

class _FoodDetailSheetState extends State<FoodDetailSheet> {
  late Food _food;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _food = widget.food;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _food.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _food.isFavorite
                        ? 'Retirer des favoris'
                        : 'Ajouter aux favoris',
                    onPressed: _busy ? null : _toggleFavorite,
                    icon: Icon(
                      _food.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _food.isFavorite
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ),
                ],
              ),
              if (_food.brand.isNotEmpty)
                Text(
                  _food.brand,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _tag(_food.category.label, Icons.category_outlined),
                  _tag(_food.referencePortion, Icons.straighten),
                  if (_food.isPersonal) _tag('Ma fiche', Icons.person_outline),
                  if (_food.barcode != null)
                    _tag('Code-barres', Icons.qr_code_2),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Valeurs pour 100 ${_food.unit.symbol}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              NutritionSummary(
                nutrition: NutritionFacts(
                  calories: _food.caloriesPer100,
                  proteinGrams: _food.proteinPer100,
                  carbohydrateGrams: _food.carbohydratePer100,
                  fatGrams: _food.fatPer100,
                ),
              ),
              if (!_food.nutritionIsComplete) ...[
                const SizedBox(height: 10),
                Text(
                  'Certaines valeurs nutritionnelles fournies par la base externe sont incomplètes.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => widget.onAddToJournal(_food),
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Choisir ma portion'),
                ),
              ),
              if (_food.isPersonal) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _edit(),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Modifier'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Supprimer'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String label, IconData icon) => Chip(
    avatar: Icon(icon, size: 16),
    label: Text(label),
    visualDensity: VisualDensity.compact,
  );

  Future<void> _toggleFavorite() async {
    final id = _food.id;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await widget.repository.toggleFavorite(id, userId: widget.userId);
      final refreshed = await widget.repository.getFood(
        id,
        userId: widget.userId,
      );
      if (!mounted) return;
      if (refreshed != null) setState(() => _food = refreshed);
      widget.onChanged();
    } on CatalogException catch (error) {
      _showMessage(error.message);
    } on Exception {
      _showMessage('Impossible de mettre à jour le favori.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final food = _food;
    Navigator.of(context).pop();
    await Future<void>.delayed(Duration.zero);
    if (mounted) widget.onEdit(food);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette fiche ?'),
        content: const Text(
          'Cette action supprime le produit du catalogue. Les aliments déjà ajoutés au journal conservent leur nom et leurs valeurs nutritionnelles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final id = _food.id;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await widget.repository.deletePersonalFood(id, userId: widget.userId);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onChanged();
    } on CatalogException catch (error) {
      _showMessage(error.message);
    } on Exception {
      _showMessage('Impossible de supprimer cette fiche.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
