import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../models/user.dart';
import '../../models/user_goal.dart';
import '../../models/weight_entry.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/gamification/achievement_service.dart';
import '../../widgets/profile_avatar.dart';
import '../../utils/validators.dart';
import '../auth/welcome_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../tracking/body_tracking_screen.dart';
import '../gamification/achievements_screen.dart';
import '../ai/ai_recommendations_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  final AuthService authService;

  const UserDashboardScreen({super.key, required this.authService});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  final UserRepository _userRepo = UserRepository();
  
  User? _user;
  UserGoal? _goal;
  List<WeightEntry> _weightHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = widget.authService.currentUser;
    if (user != null) {
      final goal = await _userRepo.getUserGoal(user.id);
      final history = await _userRepo.getWeightHistory(user.id);
      
      if (mounted) {
        setState(() {
          _user = user;
          _goal = goal;
          _weightHistory = history;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddWeightDialog() async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter une pesée'),
        content: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Poids (kg)', suffixText: 'kg'),
            validator: Validators.validateWeight,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(double.parse(controller.text.replaceAll(',', '.')));
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null && _user != null) {
      setState(() => _isLoading = true);
      
      try {
        final entry = WeightEntry(
          userId: _user!.id,
          weightKg: result,
          date: DateTime.now(),
        );
        
        await _userRepo.addOrUpdateWeight(entry);
        
        final updatedUser = _user!.copyWith(initialWeightKg: result);
        final newGoal = widget.authService.calculateGoals(updatedUser, _goal!.goalType);
        
        await _userRepo.updateUserAndGoals(updatedUser, newGoal);
        await widget.authService.initializeSession();
        
        // Trigger Gamification Engine
        final AchievementService achService = AchievementService();
        final unlocked = await achService.checkActionTriggers(_user!.id);
        
        await _loadData();

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
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Déconnexion')),
        ],
      ),
    );
    if (confirm != true) return;
    
    await widget.authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => WelcomeScreen(authService: widget.authService)),
      (route) => false,
    );
  }

  double _calculateProgress() {
    if (_user == null || _goal == null || _weightHistory.isEmpty) return 0.0;
    if (_goal!.goalType == 'maintenance') return 1.0;

    final initialWeight = _weightHistory.first.weightKg;
    final currentWeight = _user!.initialWeightKg!;
    final targetWeight = _goal!.targetWeightKg;

    if (initialWeight == targetWeight) return 1.0;

    double progress = 0.0;
    if (_goal!.goalType == 'weight_loss') {
      progress = (initialWeight - currentWeight) / (initialWeight - targetWeight);
    } else if (_goal!.goalType == 'weight_gain') {
      progress = (currentWeight - initialWeight) / (targetWeight - initialWeight);
    }

    return progress.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Espace'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: Theme.of(context).colorScheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: 24),
              _buildPhysicalStats(),
              const SizedBox(height: 24),
              _buildFitnessGoal(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildWeightChart(),
              const SizedBox(height: 24),
              _buildNutritionTargets(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Row(
      children: [
        ProfileAvatar(
          imagePath: _user!.profilePicturePath,
          userId: _user!.id,
          radius: 35,
          onImageChanged: (path) async {
            final updatedUser = _user!.copyWith(profilePicturePath: path, clearProfilePicture: path == null);
            await _userRepo.updateUser(updatedUser);
            await widget.authService.initializeSession();
            _loadData();
          },
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour, ${_user!.firstName}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                DateFormat.yMMMMd('fr_FR').format(DateTime.now()),
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surface),
          onPressed: () async {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EditProfileScreen(authService: widget.authService))
            );
            if (result == true) _loadData();
          },
        ),
      ],
    );
  }

  Widget _buildPhysicalStats() {
    final bmi = (_user!.initialWeightKg! / ((_user!.heightCm! / 100) * (_user!.heightCm! / 100))).toStringAsFixed(1);
    
    return Row(
      children: [
        Expanded(child: _buildStatMiniCard('Poids', '${_user!.initialWeightKg} kg', Icons.scale)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatMiniCard('Taille', '${_user!.heightCm} cm', Icons.height)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatMiniCard('IMC', bmi, Icons.monitor_weight_outlined)),
      ],
    );
  }

  Widget _buildStatMiniCard(String title, String value, IconData icon) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildFitnessGoal() {
    if (_goal == null) return const SizedBox.shrink();
    
    final progress = _calculateProgress();
    String goalText = 'Maintien du poids';
    if (_goal!.goalType == 'weight_loss') goalText = 'Perte de poids';
    if (_goal!.goalType == 'weight_gain') goalText = 'Prise de poids';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Objectif Actuel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(goalText, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGoalLabel('Départ', '${_weightHistory.isNotEmpty ? _weightHistory.first.weightKg : _user!.initialWeightKg} kg'),
                _buildGoalLabel('Actuel', '${_user!.initialWeightKg} kg', isHighlight: true),
                _buildGoalLabel('Cible', '${_goal!.targetWeightKg} kg'),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text('${(progress * 100).toStringAsFixed(1)}% accompli', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalLabel(String label, String value, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(
          fontWeight: FontWeight.bold, 
          fontSize: 16,
          color: isHighlight ? Theme.of(context).colorScheme.primary : null
        )),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BodyTrackingScreen(authService: widget.authService))
              );
            },
            icon: const Icon(Icons.straighten, size: 16),
            label: const Text('Mensurations', style: TextStyle(fontSize: 11)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AchievementsScreen(authService: widget.authService))
              );
            },
            icon: const Icon(Icons.emoji_events, size: 16),
            label: const Text('Trophées', style: TextStyle(fontSize: 11)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AiRecommendationsScreen(authService: widget.authService))
              );
            },
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Coach AI', style: TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }

  Widget _buildWeightChart() {
    if (_weightHistory.isEmpty) return const SizedBox.shrink();

    List<FlSpot> spots = [];
    double minX = double.maxFinite;
    double maxX = -double.maxFinite;
    double minY = double.maxFinite;
    double maxY = -double.maxFinite;

    for (int i = 0; i < _weightHistory.length; i++) {
      final entry = _weightHistory[i];
      // Utiliser l'index comme X, ou le timestamp si on préfère. 
      // Pour faire simple et espacé équitablement, utilisons l'index.
      final x = i.toDouble();
      final y = entry.weightKg;
      spots.add(FlSpot(x, y));

      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    // Ajouter une petite marge au graphique
    minY = (minY - 2).floorToDouble();
    maxY = (maxY + 2).ceilToDouble();
    if (minX == maxX) {
      maxX += 1; // Éviter l'erreur si un seul point
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Suivi du Poids', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                OutlinedButton.icon(
                  onPressed: _showAddWeightDialog, 
                  icon: const Icon(Icons.add, size: 16), 
                  label: const Text('Pesée', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0 || value < 0 || value >= _weightHistory.length) return const SizedBox.shrink();
                          final date = _weightHistory[value.toInt()].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('${date.day}/${date.month}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          );
                        },
                      ),
                    ),
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
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ),
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

  Widget _buildNutritionTargets() {
    if (_goal == null) return const SizedBox.shrink();
    
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Objectifs Journaliers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMacroCircle('Kcal', _goal!.dailyCalories.toString(), Colors.orange),
                _buildMacroCircle('Prot.', '${_goal!.proteinGrams}g', Colors.redAccent),
                _buildMacroCircle('Gluc.', '${_goal!.carbsGrams}g', Colors.blueAccent),
                _buildMacroCircle('Lip.', '${_goal!.fatGrams}g', Colors.amber),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroCircle(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5), width: 4),
          ),
          child: Center(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}