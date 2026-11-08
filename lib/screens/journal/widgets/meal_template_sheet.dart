import 'package:flutter/material.dart';

import '../../../models/food.dart';
import '../../../models/meal_food_entry.dart';
import '../../../models/meal_template.dart';
import '../../../repositories/meal_journal_repository.dart';
import '../../../theme/fit_theme.dart';

class MealTemplateSheet extends StatefulWidget {
  const MealTemplateSheet({
    super.key,
    required this.userId,
    required this.targetSlot,
    required this.targetDate,
    required this.onTemplateApplied,
  });

  final String userId;
  final MealSlot targetSlot;
  final DateTime targetDate;
  final VoidCallback onTemplateApplied;

  @override
  State<MealTemplateSheet> createState() => _MealTemplateSheetState();
}

class _MealTemplateSheetState extends State<MealTemplateSheet> {
  final MealJournalRepository _journalRepo = MealJournalRepository.instance;

  List<MealTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    try {
      final list = await _journalRepo.getTemplates(widget.userId);
      if (mounted) {
        setState(() {
          _templates = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _applyTemplate(MealTemplate template) async {
    if (template.id == null) return;
    try {
      await _journalRepo.applyTemplateToMealSlot(
        userId: widget.userId,
        templateId: template.id!,
        targetSlot: widget.targetSlot,
        targetDate: widget.targetDate,
      );
      widget.onTemplateApplied();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'application du modèle : $e')),
        );
      }
    }
  }

  Future<void> _deleteTemplate(int templateId) async {
    await _journalRepo.deleteTemplate(templateId, widget.userId);
    _loadTemplates();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Modèles de Repas pour ${widget.targetSlot.label}',
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: FitTheme.lime))
                : _templates.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun modèle enregistré.\nSauvegardez un repas depuis la liste principale !',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: FitTheme.muted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _templates.length,
                        itemBuilder: (ctx, index) {
                          final template = _templates[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        template.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                        onPressed: template.id != null
                                            ? () => _deleteTemplate(template.id!)
                                            : null,
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${template.items.length} aliments • ${template.totalCalories.round()} kcal',
                                    style: const TextStyle(color: FitTheme.muted, fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    children: template.items.map((item) {
                                      return Chip(
                                        label: Text('${item.foodName} (${item.amount.round()}g)'),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _applyTemplate(template),
                                      icon: const Icon(Icons.add_task, color: FitTheme.lime),
                                      label: const Text('Insérer ce modèle'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
