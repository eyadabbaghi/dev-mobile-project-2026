import 'package:flutter/material.dart';
import '../../models/gamification/achievement.dart';
import '../../models/gamification/user_gamification.dart';
import '../../services/auth_service.dart';
import '../../services/gamification/achievement_service.dart';

class AchievementsScreen extends StatefulWidget {
  final AuthService authService;

  const AchievementsScreen({super.key, required this.authService});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final AchievementService _service = AchievementService();
  UserGamification? _stats;
  List<Achievement> _achievements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = widget.authService.currentUser;
    if (user != null) {
      final stats = await _service.getUserGamification(user.id);
      final list = await _service.getAchievements(user.id);
      if (mounted) {
        setState(() {
          _stats = stats;
          _achievements = list;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _stats == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Progress to next level
    final currentLevelXp = (_stats!.level - 1) * 1000;
    final nextLevelXp = _stats!.level * 1000;
    final xpInCurrentLevel = _stats!.xp - currentLevelXp;
    final progress = xpInCurrentLevel / 1000;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes Trophées')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: XP & Level
            Card(
              margin: EdgeInsets.zero,
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text('Niveau ${_stats!.level}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: 8),
                    Text('${_stats!.xp} XP Total', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(6),
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$currentLevelXp XP', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        Text('Prochain niveau: $nextLevelXp XP', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStreakInfo('Série Actuelle', '${_stats!.currentStreak} j', Icons.local_fire_department, Colors.orange),
                        _buildStreakInfo('Record', '${_stats!.longestStreak} j', Icons.emoji_events, Colors.amber),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Trophées', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._achievements.map((a) => _buildAchievementTile(a)),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakInfo(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildAchievementTile(Achievement a) {
    final color = a.isUnlocked ? Theme.of(context).colorScheme.primary : Colors.grey.withValues(alpha: 0.3);
    
    // Convert Material Icon Name (string) to IconData for simple display
    IconData iconData = Icons.star;
    switch(a.iconName) {
      case 'emoji_events': iconData = Icons.emoji_events; break;
      case 'local_fire_department': iconData = Icons.local_fire_department; break;
      case 'timeline': iconData = Icons.timeline; break;
      case 'military_tech': iconData = Icons.military_tech; break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(iconData, color: color),
        ),
        title: Text(a.title, style: TextStyle(fontWeight: FontWeight.bold, color: a.isUnlocked ? Colors.white : Colors.grey)),
        subtitle: Text(a.description, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        trailing: Text('+${a.xpReward} XP', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
