import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../repositories/user_repository.dart';
import '../../models/user_goal.dart';
import '../auth/welcome_screen.dart';
import '../../widgets/profile_avatar.dart';
import 'edit_profile_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final AuthService authService;
  const UserProfileScreen({super.key, required this.authService});
  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserRepository _userRepo = UserRepository();
  UserGoal? _goal;
  bool _isLoading = true;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = widget.authService.currentUser;
    if (user != null) {
      _goal = await _userRepo.getUserGoal(user.id);
      _biometricEnabled = await widget.authService.isBiometricEnabledForCurrentUser();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleBiometrics(bool value) async {
    try {
      if (value) {
        await widget.authService.enableBiometricLogin();
      } else {
        await widget.authService.disableBiometricLogin();
      }
      setState(() => _biometricEnabled = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    final user = widget.authService.currentUser!;
    final bmi = (user.initialWeightKg! / ((user.heightCm! / 100) * (user.heightCm! / 100))).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit), 
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EditProfileScreen(authService: widget.authService))
              );
              if (result == true) {
                setState(() => _isLoading = true);
                _loadData();
              }
            }
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            ProfileAvatar(
              imagePath: user.profilePicturePath,
              userId: user.id,
              onImageChanged: (path) async {
                final updatedUser = user.copyWith(profilePicturePath: path, clearProfilePicture: path == null);
                await _userRepo.updateUser(updatedUser);
                await widget.authService.initializeSession();
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            Text('${user.firstName} ${user.lastName}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(user.email, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            
            _buildStatCard('Physique', [
              _StatRow('Âge', '${user.age} ans'),
              _StatRow('Taille', '${user.heightCm} cm'),
              _StatRow('Poids actuel', '${user.initialWeightKg} kg'),
              _StatRow('IMC', bmi),
            ]),
            
            const SizedBox(height: 16),
            
            Card(
              child: SwitchListTile(
                value: _biometricEnabled,
                onChanged: _toggleBiometrics,
                title: const Text('Connexion biométrique', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Utiliser Face ID / Empreinte digitale', style: TextStyle(fontSize: 12, color: Colors.grey)),
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ),

            if (_goal != null)
              _buildStatCard('Objectifs', [
                _StatRow('Objectif', _goal!.goalType == 'weight_loss' ? 'Perte' : _goal!.goalType == 'weight_gain' ? 'Prise' : 'Maintien'),
                _StatRow('Poids cible', '${_goal!.targetWeightKg} kg'),
                _StatRow('Calories/jour', '${_goal!.dailyCalories} kcal', isHighlight: true),
                _StatRow('Protéines', '${_goal!.proteinGrams} g'),
                _StatRow('Glucides', '${_goal!.carbsGrams} g'),
                _StatRow('Lipides', '${_goal!.fatGrams} g'),
                _StatRow('Eau', '${_goal!.dailyWaterMl} ml'),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, List<_StatRow> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const Divider(),
            ...rows.map((row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(row.label, style: const TextStyle(color: Colors.grey)),
                  Text(row.value, style: TextStyle(fontWeight: row.isHighlight ? FontWeight.bold : FontWeight.normal, color: row.isHighlight ? Theme.of(context).colorScheme.primary : null)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _StatRow {
  final String label;
  final String value;
  final bool isHighlight;
  _StatRow(this.label, this.value, {this.isHighlight = false});
}