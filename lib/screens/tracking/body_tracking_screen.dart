import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/body_measurement.dart';
import '../../repositories/tracking_repository.dart';
import '../../services/auth_service.dart';
import '../../services/gamification/achievement_service.dart';
import '../../utils/validators.dart';

class BodyTrackingScreen extends StatefulWidget {
  final AuthService authService;
  
  const BodyTrackingScreen({super.key, required this.authService});

  @override
  State<BodyTrackingScreen> createState() => _BodyTrackingScreenState();
}

class _BodyTrackingScreenState extends State<BodyTrackingScreen> {
  final TrackingRepository _repo = TrackingRepository();
  final AchievementService _achievementService = AchievementService();
  
  List<BodyMeasurement> _measurements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = widget.authService.currentUser;
    if (user != null) {
      final list = await _repo.getMeasurements(user.id);
      if (mounted) {
        setState(() {
          _measurements = list;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddMeasurementDialog() async {
    final formKey = GlobalKey<FormState>();
    final waistCtrl = TextEditingController();
    final chestCtrl = TextEditingController();
    final armCtrl = TextEditingController();
    final hipCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelles mensurations'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: waistCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Taille (cm)'),
                  validator: (v) => v!.isNotEmpty && double.tryParse(v.replaceAll(',', '.')) == null ? 'Invalide' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: chestCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Poitrine (cm)'),
                  validator: (v) => v!.isNotEmpty && double.tryParse(v.replaceAll(',', '.')) == null ? 'Invalide' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: armCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Bras (cm)'),
                  validator: (v) => v!.isNotEmpty && double.tryParse(v.replaceAll(',', '.')) == null ? 'Invalide' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: hipCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Hanches (cm)'),
                  validator: (v) => v!.isNotEmpty && double.tryParse(v.replaceAll(',', '.')) == null ? 'Invalide' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                if (waistCtrl.text.isEmpty && chestCtrl.text.isEmpty && armCtrl.text.isEmpty && hipCtrl.text.isEmpty) {
                  return;
                }
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      
      final m = BodyMeasurement(
        userId: widget.authService.currentUser!.id,
        date: DateTime.now(),
        waistCm: waistCtrl.text.isNotEmpty ? double.parse(waistCtrl.text.replaceAll(',', '.')) : null,
        chestCm: chestCtrl.text.isNotEmpty ? double.parse(chestCtrl.text.replaceAll(',', '.')) : null,
        armCm: armCtrl.text.isNotEmpty ? double.parse(armCtrl.text.replaceAll(',', '.')) : null,
        hipCm: hipCtrl.text.isNotEmpty ? double.parse(hipCtrl.text.replaceAll(',', '.')) : null,
      );

      await _repo.addMeasurement(m);
      
      // Trigger Gamification Engine
      final unlocked = await _achievementService.checkActionTriggers(widget.authService.currentUser!.id);
      
      await _loadData();
      
      // Afficher les achievements débloqués s'il y en a
      if (mounted && unlocked.isNotEmpty) {
        for (var a in unlocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.stars, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Succès débloqué : ${a.title} (+${a.xpReward} XP)')),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Mensurations')),
      body: _measurements.isEmpty 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.straighten, size: 80, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                const Text('Aucune mesure enregistrée.'),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _showAddMeasurementDialog, 
                  icon: const Icon(Icons.add), 
                  label: const Text('Ajouter')
                )
              ],
            )
          )
        : RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildChartCard('Tour de taille (cm)', (m) => m.waistCm),
                  const SizedBox(height: 16),
                  _buildChartCard('Poitrine (cm)', (m) => m.chestCm),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _showAddMeasurementDialog, 
                    icon: const Icon(Icons.add), 
                    label: const Text('Nouvelles mesures')
                  )
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildChartCard(String title, double? Function(BodyMeasurement) selector) {
    List<FlSpot> spots = [];
    double minX = double.maxFinite;
    double maxX = -double.maxFinite;
    double minY = double.maxFinite;
    double maxY = -double.maxFinite;

    int spotIndex = 0;
    for (var m in _measurements) {
      final val = selector(m);
      if (val != null) {
        final x = spotIndex.toDouble();
        spots.add(FlSpot(x, val));
        
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (val < minY) minY = val;
        if (val > maxY) maxY = val;
        spotIndex++;
      }
    }

    if (spots.isEmpty) return const SizedBox.shrink();

    minY = (minY - 2).floorToDouble();
    maxY = (maxY + 2).ceilToDouble();
    if (minX == maxX) maxX += 1;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}