import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/catalog_exception.dart';
import '../../database/catalog_repository.dart';
import '../../models/food.dart';

class FoodFormScreen extends StatefulWidget {
  const FoodFormScreen({
    super.key,
    required this.userId,
    required this.repository,
    this.initialFood,
  });

  final String userId;
  final CatalogRepository repository;
  final Food? initialFood;

  @override
  State<FoodFormScreen> createState() => _FoodFormScreenState();
}

class _FoodFormScreenState extends State<FoodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _portionController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbohydrateController;
  late final TextEditingController _fatController;

  late FoodCategory _category;
  late FoodUnit _unit;
  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.initialFood != null;

  @override
  void initState() {
    super.initState();
    final food = widget.initialFood;
    _nameController = TextEditingController(text: food?.name ?? '');
    _brandController = TextEditingController(text: food?.brand ?? '');
    _portionController = TextEditingController(
      text: food?.referencePortion ?? '100 g',
    );
    _barcodeController = TextEditingController(text: food?.barcode ?? '');
    _caloriesController = TextEditingController(
      text: food == null ? '' : _number(food.caloriesPer100),
    );
    _proteinController = TextEditingController(
      text: food == null ? '' : _number(food.proteinPer100),
    );
    _carbohydrateController = TextEditingController(
      text: food == null ? '' : _number(food.carbohydratePer100),
    );
    _fatController = TextEditingController(
      text: food == null ? '' : _number(food.fatPer100),
    );
    _category = food?.category ?? FoodCategory.other;
    _unit = food?.unit ?? FoodUnit.gram;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _portionController.dispose();
    _barcodeController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbohydrateController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le produit' : 'Nouvel aliment'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Informations du produit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Le nom est obligatoire.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brandController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Marque',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FoodCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Catégorie',
                border: OutlineInputBorder(),
              ),
              items: FoodCategory.values
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _portionController,
                    textCapitalization: TextCapitalization.none,
                    decoration: const InputDecoration(
                      labelText: 'Portion de référence *',
                      hintText: 'ex. 1 pot (125 g)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Indiquez une portion de référence.'
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<FoodUnit>(
                    initialValue: _unit,
                    decoration: const InputDecoration(
                      labelText: 'Unité',
                      border: OutlineInputBorder(),
                    ),
                    items: FoodUnit.values
                        .map(
                          (unit) => DropdownMenuItem(
                            value: unit,
                            child: Text(unit.symbol),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _unit = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Valeurs nutritionnelles pour 100 ${_unit.symbol}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Saisissez les valeurs de l’étiquette nutritionnelle. La portion sera recalculée à partir de cette base.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            _numberField(_caloriesController, 'Calories (kcal) *'),
            const SizedBox(height: 12),
            _numberField(_proteinController, 'Protéines (g) *'),
            const SizedBox(height: 12),
            _numberField(_carbohydrateController, 'Glucides (g) *'),
            const SizedBox(height: 12),
            _numberField(_fatController, 'Lipides (g) *'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcodeController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Code-barres (facultatif)',
                helperText:
                    '8 à 14 chiffres pour retrouver cette fiche au scan.',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final barcode = value?.trim() ?? '';
                if (barcode.isNotEmpty &&
                    !RegExp(r'^\d{8,14}$').hasMatch(barcode)) {
                  return 'Le code doit contenir entre 8 et 14 chiffres.';
                }
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,3}')),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final number = _parseNumber(value);
        if (number == null) return 'Saisissez une valeur numérique.';
        if (!number.isFinite || number < 0) {
          return 'La valeur doit être positive ou nulle.';
        }
        return null;
      },
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
      _saving = true;
    });
    if (!_formKey.currentState!.validate()) {
      setState(() => _saving = false);
      return;
    }

    final existing = widget.initialFood;
    final now = DateTime.now();
    final food = Food(
      id: existing?.id,
      name: _nameController.text.trim(),
      brand: _brandController.text.trim(),
      category: _category,
      referencePortion: _portionController.text.trim(),
      unit: _unit,
      caloriesPer100: _parseNumber(_caloriesController.text)!,
      proteinPer100: _parseNumber(_proteinController.text)!,
      carbohydratePer100: _parseNumber(_carbohydrateController.text)!,
      fatPer100: _parseNumber(_fatController.text)!,
      ownerId: existing?.ownerId,
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      isBuiltIn: false,
      nutritionIsComplete: true,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      isFavorite: false,
    );

    try {
      final saved = await widget.repository.savePersonalFood(
        food,
        userId: widget.userId,
      );
      if (mounted) Navigator.of(context).pop<Food>(saved);
    } on CatalogException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
          _saving = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _errorMessage = 'Une erreur est survenue pendant l’enregistrement.';
          _saving = false;
        });
      }
    }
  }

  static double? _parseNumber(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  static String _number(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}
