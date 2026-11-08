import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/water_intake_entry.dart';
import '../../../repositories/water_repository.dart';
import '../../../theme/fit_theme.dart';

class WaterLogDialog extends StatefulWidget {
  const WaterLogDialog({
    super.key,
    required this.userId,
    required this.date,
    required this.onWaterUpdated,
  });

  final String userId;
  final DateTime date;
  final VoidCallback onWaterUpdated;

  @override
  State<WaterLogDialog> createState() => _WaterLogDialogState();
}

class _WaterLogDialogState extends State<WaterLogDialog> {
  final WaterRepository _waterRepo = WaterRepository.instance;
  final TextEditingController _customAmountController = TextEditingController();

  List<WaterIntakeEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    try {
      final list = await _waterRepo.getWaterEntriesForDate(widget.userId, widget.date);
      if (mounted) {
        setState(() {
          _entries = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addWater(int amountMl) async {
    if (amountMl <= 0) return;
    await _waterRepo.addWaterIntake(
      userId: widget.userId,
      amountMl: amountMl,
      consumedAt: DateTime(
        widget.date.year,
        widget.date.month,
        widget.date.day,
        DateTime.now().hour,
        DateTime.now().minute,
      ),
    );
    _customAmountController.clear();
    widget.onWaterUpdated();
    _loadEntries();
  }

  Future<void> _deleteEntry(int id) async {
    await _waterRepo.deleteWaterIntake(id, widget.userId);
    widget.onWaterUpdated();
    _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    final totalMl = _entries.fold(0, (sum, item) => sum + item.amountMl);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.water_drop, color: Colors.lightBlueAccent),
                  const SizedBox(width: 8),
                  Text(
                    'Suivi Hydrique ($totalMl ml)',
                    style: const TextStyle(
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
          // Saisie rapide
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addWater(250),
                  icon: const Icon(Icons.local_drink, color: Colors.lightBlueAccent),
                  label: const Text('+250 ml'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addWater(500),
                  icon: const Icon(Icons.local_hospital, color: Colors.lightBlueAccent),
                  label: const Text('+500 ml'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Saisie personnalisée
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Saisie personnalisée (ml)',
                    suffixText: 'ml',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final parsed = int.tryParse(_customAmountController.text);
                  if (parsed != null) _addWater(parsed);
                },
                child: const Text('Ajouter'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Historique des prises du jour :',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: FitTheme.lime))
                : _entries.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucune prise d\'eau enregistrée aujourd\'hui.',
                          style: TextStyle(color: FitTheme.muted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _entries.length,
                        itemBuilder: (ctx, index) {
                          final entry = _entries[index];
                          final timeStr = DateFormat('HH:mm').format(entry.consumedAt);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.water_drop, color: Colors.lightBlueAccent),
                              title: Text(
                                '+${entry.amountMl} ml',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                'À $timeStr',
                                style: const TextStyle(color: FitTheme.muted, fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: entry.id != null
                                    ? () => _deleteEntry(entry.id!)
                                    : null,
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
