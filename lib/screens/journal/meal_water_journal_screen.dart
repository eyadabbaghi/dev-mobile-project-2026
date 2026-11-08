import 'dart:io';

import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/food.dart';
import '../../models/meal_food_entry.dart';
import '../../models/user_goal.dart';
import '../../repositories/meal_journal_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/water_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/fit_theme.dart';
import 'widgets/add_meal_food_sheet.dart';
import 'widgets/meal_ai_scan_sheet.dart';
import 'widgets/meal_template_sheet.dart';
import 'widgets/water_log_dialog.dart';

class MealWaterJournalScreen extends StatefulWidget {
  const MealWaterJournalScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<MealWaterJournalScreen> createState() => _MealWaterJournalScreenState();
}

class _MealWaterJournalScreenState extends State<MealWaterJournalScreen> {
  final MealJournalRepository _journalRepo = MealJournalRepository.instance;
  final WaterRepository _waterRepo = WaterRepository.instance;
  final UserRepository _userRepo = UserRepository();
  final ImagePicker _picker = ImagePicker();

  DateTime _selectedDate = DateTime.now();
  UserGoal? _userGoal;
  List<MealFoodEntry> _mealEntries = [];
  int _waterTotalMl = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = widget.authService.currentUser;
    if (user != null) {
      final goal = await _userRepo.getUserGoal(user.id);
      final entries = await _journalRepo.getEntriesForDate(user.id, _selectedDate);
      final waterTotal = await _waterRepo.getDailyWaterTotal(user.id, _selectedDate);

      if (mounted) {
        setState(() {
          _userGoal = goal;
          _mealEntries = entries;
          _waterTotalMl = waterTotal;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeDate(int offsetDays) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offsetDays));
    });
    _loadData();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: FitTheme.lime,
              onPrimary: FitTheme.background,
              surface: FitTheme.panel,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  Future<void> _addFoodEntry(MealFoodEntry entry) async {
    await _journalRepo.addMealEntry(entry);
    _loadData();
  }

  Future<void> _deleteFoodEntry(int id) async {
    final userId = widget.authService.currentUser?.id;
    if (userId != null) {
      await _journalRepo.deleteMealEntry(id, userId);
      _loadData();
    }
  }

  Future<void> _quickAddWater(int amountMl) async {
    final userId = widget.authService.currentUser?.id;
    if (userId != null) {
      await _waterRepo.addWaterIntake(
        userId: userId,
        amountMl: amountMl,
        consumedAt: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          DateTime.now().hour,
          DateTime.now().minute,
        ),
      );
      _loadData();
    }
  }

  Future<void> _openAiScanModal(MealSlot slot) async {
    final userId = widget.authService.currentUser?.id;
    if (userId == null) return;

    final pickedSource = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: FitTheme.lime),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: FitTheme.lime),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (pickedSource == null) return;

    final pickedFile = await _picker.pickImage(source: pickedSource);
    if (pickedFile == null) return;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => MealAiScanSheet(
        imageFile: File(pickedFile.path),
        userId: userId,
        mealSlot: slot,
        onEntriesConfirmed: (entries) async {
          for (final entry in entries) {
            final entryForDate = MealFoodEntry(
              userId: entry.userId,
              foodName: entry.foodName,
              brand: entry.brand,
              amount: entry.amount,
              unit: entry.unit,
              calories: entry.calories,
              proteinGrams: entry.proteinGrams,
              carbohydrateGrams: entry.carbohydrateGrams,
              fatGrams: entry.fatGrams,
              mealSlot: entry.mealSlot,
              consumedAt: DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
                DateTime.now().hour,
                DateTime.now().minute,
              ),
            );
            await _journalRepo.addMealEntry(entryForDate);
          }
          _loadData();
        },
      ),
    );
  }

  Future<void> _copySlotFromPreviousDate(MealSlot slot) async {
    final userId = widget.authService.currentUser?.id;
    if (userId == null) return;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate.subtract(const Duration(days: 1)),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: 'Sélectionner le jour source à copier',
    );

    if (pickedDate != null) {
      await _journalRepo.copyMealSlot(
        userId: userId,
        slot: slot,
        fromDate: pickedDate,
        toDate: _selectedDate,
      );
      _loadData();
    }
  }

  Future<void> _saveSlotAsTemplate(MealSlot slot, List<MealFoodEntry> entries) async {
    final userId = widget.authService.currentUser?.id;
    if (userId == null || entries.isEmpty) return;

    final controller = TextEditingController(text: 'Mon ${slot.label}');

    final templateName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sauvegarder en Modèle (${slot.label})'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nom du modèle'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (templateName != null && templateName.isNotEmpty) {
      await _journalRepo.saveMealSlotAsTemplate(
        userId: userId,
        templateName: templateName,
        slot: slot,
        entries: entries,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Modèle "$templateName" enregistré avec succès !')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.authService.currentUser?.id ?? '';

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: FitTheme.lime))
          : RefreshIndicator(
              color: FitTheme.lime,
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDateHeader(),
                    const SizedBox(height: 16),
                    _buildCalorieSummaryCard(),
                    const SizedBox(height: 16),
                    _buildWaterCard(userId),
                    const SizedBox(height: 20),
                    const Text(
                      'Journal des Repas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...MealSlot.values.map((slot) => _buildMealSlotCard(slot, userId)),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateHeader() {
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final dateStr = DateFormat('EEEE d MMMM', 'fr_FR').format(_selectedDate);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: () => _changeDate(-1),
            ),
            GestureDetector(
              onTap: _pickDate,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: FitTheme.lime),
                  const SizedBox(width: 8),
                  Text(
                    isToday ? 'Aujourd\'hui' : dateStr[0].toUpperCase() + dateStr.substring(1),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: () => _changeDate(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieSummaryCard() {
    final dailyGoalCal = _userGoal?.dailyCalories ?? 2000;
    final totalConsumedCal = _mealEntries.fold(0.0, (sum, item) => sum + item.calories);
    final remainingCal = dailyGoalCal - totalConsumedCal.round();

    final totalProtein = _mealEntries.fold(0.0, (sum, item) => sum + item.proteinGrams);
    final totalCarbs = _mealEntries.fold(0.0, (sum, item) => sum + item.carbohydrateGrams);
    final totalFat = _mealEntries.fold(0.0, (sum, item) => sum + item.fatGrams);

    final targetProtein = _userGoal?.proteinGrams ?? 150;
    final targetCarbs = _userGoal?.carbsGrams ?? 200;
    final targetFat = _userGoal?.fatGrams ?? 65;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCalorieStat('Objectif', '$dailyGoalCal', FitTheme.muted),
                _buildCalorieStat('Consommé', '${totalConsumedCal.round()}', Colors.white),
                _buildCalorieStat(
                  'Restant',
                  '$remainingCal',
                  remainingCal >= 0 ? FitTheme.lime : Colors.redAccent,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: FitTheme.border),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMacroProgress('Protéines', totalProtein, targetProtein, Colors.orangeAccent)),
                const SizedBox(width: 12),
                Expanded(child: _buildMacroProgress('Glucides', totalCarbs, targetCarbs, Colors.lightBlueAccent)),
                const SizedBox(width: 12),
                Expanded(child: _buildMacroProgress('Lipides', totalFat, targetFat, Colors.redAccent)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: valueColor),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: FitTheme.muted),
        ),
      ],
    );
  }

  Widget _buildMacroProgress(String label, double current, int target, Color color) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: FitTheme.muted)),
            Text('${current.round()}/${target}g', style: const TextStyle(fontSize: 11, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: FitTheme.border,
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildWaterCard(String userId) {
    final targetWaterMl = _userGoal?.dailyWaterMl ?? 2000;
    final progress = targetWaterMl > 0 ? (_waterTotalMl / targetWaterMl).clamp(0.0, 1.0) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.water_drop, color: Colors.lightBlueAccent),
                    SizedBox(width: 8),
                    Text(
                      'Hydratation',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.history, color: FitTheme.muted),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (ctx) => WaterLogDialog(
                        userId: userId,
                        date: _selectedDate,
                        onWaterUpdated: _loadData,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_waterTotalMl / $targetWaterMl ml',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(color: FitTheme.muted, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: FitTheme.border,
              color: Colors.lightBlueAccent,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _quickAddWater(250),
                    icon: const Icon(Icons.local_drink, size: 18, color: Colors.lightBlueAccent),
                    label: const Text('+250 ml'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _quickAddWater(500),
                    icon: const Icon(Icons.local_hospital, size: 18, color: Colors.lightBlueAccent),
                    label: const Text('+500 ml'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSlotCard(MealSlot slot, String userId) {
    final slotEntries = _mealEntries.where((e) => e.mealSlot == slot).toList();
    final slotCalories = slotEntries.fold(0.0, (sum, e) => sum + e.calories);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  slot.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${slotCalories.round()} kcal',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: FitTheme.lime,
                        fontSize: 15,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: FitTheme.muted),
                      onSelected: (action) {
                        if (action == 'copy') {
                          _copySlotFromPreviousDate(slot);
                        } else if (action == 'template_save') {
                          _saveSlotAsTemplate(slot, slotEntries);
                        } else if (action == 'template_apply') {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (ctx) => MealTemplateSheet(
                              userId: userId,
                              targetSlot: slot,
                              targetDate: _selectedDate,
                              onTemplateApplied: _loadData,
                            ),
                          );
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'copy',
                          child: Row(
                            children: [
                              Icon(Icons.copy, size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Copier depuis un autre jour'),
                            ],
                          ),
                        ),
                        if (slotEntries.isNotEmpty)
                          const PopupMenuItem(
                            value: 'template_save',
                            child: Row(
                              children: [
                                Icon(Icons.bookmark_add, size: 18, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Enregistrer comme modèle'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'template_apply',
                          child: Row(
                            children: [
                              Icon(Icons.folder_special, size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Insérer un modèle'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (slotEntries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Aucun aliment enregistré.',
                  style: TextStyle(color: FitTheme.muted, fontSize: 13),
                ),
              )
            else
              Column(
                children: slotEntries.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.foodName,
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              Text(
                                '${item.amount.round()} ${item.unit == FoodUnit.gram ? "g" : "ml"}${item.brand.isNotEmpty ? " • ${item.brand}" : ""}',
                                style: const TextStyle(color: FitTheme.muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${item.calories.round()} kcal',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                              onPressed: item.id != null ? () => _deleteFoodEntry(item.id!) : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (ctx) => AddMealFoodSheet(
                          userId: userId,
                          mealSlot: slot,
                          onFoodAdded: _addFoodEntry,
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 18, color: FitTheme.lime),
                    label: const Text('Ajouter'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openAiScanModal(slot),
                  icon: const Icon(Icons.auto_awesome, size: 18, color: FitTheme.lime),
                  label: const Text('IA Photo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
