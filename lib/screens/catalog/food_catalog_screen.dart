import 'dart:async';

import '../../theme/fit_theme.dart';

import 'package:flutter/material.dart';

import '../../database/catalog_exception.dart';
import '../../database/catalog_repository.dart';
import '../../models/food.dart';
import '../../models/meal_food_entry.dart';
import 'barcode_scanner_screen.dart';
import 'food_detail_sheet.dart';
import 'food_form_screen.dart';
import 'food_portion_sheet.dart';

class FoodCatalogScreen extends StatefulWidget {
  const FoodCatalogScreen({
    super.key,
    required this.currentUserId,
    this.repository,
  });

  final String currentUserId;
  final CatalogRepository? repository;

  @override
  State<FoodCatalogScreen> createState() => _FoodCatalogScreenState();
}

class _FoodCatalogScreenState extends State<FoodCatalogScreen> {
  late final CatalogRepository _repository;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<Food> _foods = const [];
  FoodCategory? _selectedCategory;
  int _collection = 0;
  bool _loading = true;
  String? _errorMessage;
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CatalogRepository.instance;
    _loadFoods();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFoods({bool showLoading = true}) async {
    final token = ++_requestToken;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      final foods = await _repository.listFoods(
        userId: widget.currentUserId,
        search: _searchController.text,
        category: _selectedCategory,
      );
      if (!mounted || token != _requestToken) return;
      setState(() {
        _foods = foods;
        _loading = false;
        _errorMessage = null;
      });
    } on CatalogException catch (error) {
      if (!mounted || token != _requestToken) return;
      setState(() {
        _loading = false;
        _errorMessage = error.message;
      });
    } on Exception {
      if (!mounted || token != _requestToken) return;
      setState(() {
        _loading = false;
        _errorMessage =
            'Une erreur est survenue lors du chargement du catalogue.';
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _loadFoods(showLoading: false);
    });
  }

  Future<void> _openScanner() async {
    final food = await Navigator.of(context).push<Food>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          userId: widget.currentUserId,
          repository: _repository,
        ),
      ),
    );
    if (!mounted || food == null) return;
    await _loadFoods(showLoading: false);
    await _openDetails(food);
  }

  Future<void> _openCreateForm() async {
    final saved = await Navigator.of(context).push<Food>(
      MaterialPageRoute(
        builder: (_) => FoodFormScreen(
          userId: widget.currentUserId,
          repository: _repository,
        ),
      ),
    );
    if (saved == null || !mounted) return;
    await _loadFoods(showLoading: false);
    _showMessage('Produit ajouté au catalogue.');
  }

  Future<void> _editFood(Food food) async {
    final saved = await Navigator.of(context).push<Food>(
      MaterialPageRoute(
        builder: (_) => FoodFormScreen(
          userId: widget.currentUserId,
          repository: _repository,
          initialFood: food,
        ),
      ),
    );
    if (saved == null || !mounted) return;
    await _loadFoods(showLoading: false);
    _showMessage('Fiche mise à jour.');
  }

  Future<void> _openDetails(Food food) async {
    if (food.id == null) return;
    final currentFood = await _repository.getFood(
      food.id!,
      userId: widget.currentUserId,
    );
    if (!mounted || currentFood == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FoodDetailSheet(
        food: currentFood,
        userId: widget.currentUserId,
        repository: _repository,
        onChanged: () => _loadFoods(showLoading: false),
        onEdit: _editFood,
        onAddToJournal: _addToJournal,
      ),
    );
    if (mounted) await _loadFoods(showLoading: false);
  }

  Future<void> _addToJournal(Food food) async {
    final entry = await FoodPortionSheet.show(
      context,
      food: food,
      userId: widget.currentUserId,
    );
    if (entry == null || !mounted) return;

    try {
      await _repository.addJournalEntry(entry);
      if (mounted) {
        _showMessage(
          '${food.name} ajouté au créneau « ${entry.mealSlot.label} ».',
        );
      }
    } on CatalogException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Exception {
      if (mounted) _showMessage('Impossible d’ajouter cet aliment au journal.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: FitTheme.lime,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.restaurant_rounded,
                            color: FitTheme.background,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'FitTrack ',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                  text: 'AI',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    color: FitTheme.lime,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: _openScanner,
                          tooltip: 'Scanner un code-barres',
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Bien manger,',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 32,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const Text(
                      'commence ici.',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 32,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: FitTheme.lime,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Trouvez vos aliments. Ajustez vos portions.',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: FitTheme.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SearchBar(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      hintText: 'Rechercher un aliment, une marque...',
                      leading: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.search_rounded,
                          color: FitTheme.muted,
                        ),
                      ),
                      trailing: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Effacer la recherche',
                            onPressed: () {
                              _searchController.clear();
                              _loadFoods(showLoading: false);
                            },
                            icon: const Icon(Icons.close, size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _collectionTab('Tous', 0),
                        const SizedBox(width: 8),
                        _collectionTab('Favoris', 1),
                        const SizedBox(width: 8),
                        _collectionTab('Mes aliments', 2),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _categoryChip('Tout', null),
                          ...FoodCategory.values.map(
                            (category) =>
                                _categoryChip(category.label, category),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Votre catalogue',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!_loading)
                          Text(
                            '${_visibleFoods.length} aliments',
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: FitTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
          body: _buildFoodList(theme),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FitTheme.panel,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: FitTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _openScanner,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 21),
                    label: const Text('Scanner'),
                  ),
                ),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openCreateForm,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Créer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Food> get _visibleFoods => _foods
      .where(
        (food) => switch (_collection) {
          1 => food.isFavorite,
          2 => food.ownerId == widget.currentUserId,
          _ => true,
        },
      )
      .toList();

  Widget _collectionTab(String label, int value) => Expanded(
    child: ChoiceChip(
      showCheckmark: false,
      labelPadding: const EdgeInsets.symmetric(horizontal: 5),
      label: SizedBox(
        width: double.infinity,
        child: Text(label, textAlign: TextAlign.center),
      ),
      labelStyle: TextStyle(
        fontFamily: 'Roboto',
        color: _collection == value ? FitTheme.background : FitTheme.muted,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      selected: _collection == value,
      onSelected: (_) => setState(() => _collection = value),
    ),
  );

  Widget _categoryChip(String label, FoodCategory? category) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: FilterChip(
      showCheckmark: false,
      label: Text(label),
      selectedColor: const Color(0xFF303D1B),
      labelStyle: TextStyle(
        fontFamily: 'Roboto',
        color: _selectedCategory == category ? FitTheme.lime : FitTheme.muted,
        fontSize: 11,
      ),
      selected: _selectedCategory == category,
      onSelected: (_) {
        setState(() => _selectedCategory = category);
        _loadFoods(showLoading: false);
      },
    ),
  );

  Widget _buildFoodList(ThemeData theme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 42,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _loadFoods(),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    if (_visibleFoods.isEmpty) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 44,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                _searchController.text.isEmpty
                    ? 'Aucun aliment dans cette catégorie.'
                    : 'Aucun résultat pour cette recherche.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Essayez un autre filtre ou ajoutez votre propre produit.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadFoods(showLoading: false),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(22, 2, 22, 16),
        itemCount: _visibleFoods.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final food = _visibleFoods[index];
          return _FoodCard(
            food: food,
            onTap: () => _openDetails(food),
            onFavorite: () => _toggleFavorite(food),
          );
        },
      ),
    );
  }

  Future<void> _toggleFavorite(Food food) async {
    final id = food.id;
    if (id == null) return;
    try {
      await _repository.toggleFavorite(id, userId: widget.currentUserId);
      await _loadFoods(showLoading: false);
    } on CatalogException catch (error) {
      _showMessage(error.message);
    } on Exception {
      _showMessage('Impossible de mettre à jour vos favoris.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({
    required this.food,
    required this.onTap,
    required this.onFavorite,
  });

  final Food food;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = food.brand.isEmpty
        ? food.category.label
        : '${food.brand} · ${food.category.label}';

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF2B3320),
                foregroundColor: FitTheme.lime,
                child: Icon(_categoryIcon(food.category)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_format(food.caloriesPer100)} kcal · P ${_format(food.proteinPer100)} g · G ${_format(food.carbohydratePer100)} g · L ${_format(food.fatPer100)} g',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onFavorite,
                tooltip: food.isFavorite
                    ? 'Retirer des favoris'
                    : 'Ajouter aux favoris',
                icon: Icon(
                  food.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: food.isFavorite ? FitTheme.lime : FitTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _categoryIcon(FoodCategory category) => switch (category) {
    FoodCategory.fruitsVegetables => Icons.eco_outlined,
    FoodCategory.cereals => Icons.grain,
    FoodCategory.proteins => Icons.egg_alt_outlined,
    FoodCategory.dairy => Icons.icecream_outlined,
    FoodCategory.fats => Icons.water_drop_outlined,
    FoodCategory.beverages => Icons.local_drink_outlined,
    FoodCategory.snacks => Icons.cookie_outlined,
    FoodCategory.other => Icons.restaurant_outlined,
  };

  static String _format(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
