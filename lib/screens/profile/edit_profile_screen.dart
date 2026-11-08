import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../repositories/user_repository.dart';
import '../../utils/validators.dart';

class EditProfileScreen extends StatefulWidget {
  final AuthService authService;

  const EditProfileScreen({super.key, required this.authService});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserRepository _userRepo = UserRepository();
  
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _targetWeightController;
  
  late String _selectedActivity;
  late String _selectedGoal;

  // Section Mot de passe
  final _passwordFormKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  
  double _passwordStrength = 0.0;
  Color _passwordStrengthColor = Colors.red;
  bool _isChangingPassword = false;
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = widget.authService.currentUser!;
    _firstNameController = TextEditingController(text: user.firstName);
    _lastNameController = TextEditingController(text: user.lastName);
    _heightController = TextEditingController(text: user.heightCm?.toString() ?? '');
    _weightController = TextEditingController(text: user.initialWeightKg?.toString() ?? '');
    
    _selectedActivity = user.activityLevel ?? 'moderate';
    _selectedGoal = 'maintenance'; // Default, we will load the real one
    _loadCurrentGoal();
  }
  
  Future<void> _loadCurrentGoal() async {
    final user = widget.authService.currentUser!;
    final currentGoal = await _userRepo.getUserGoal(user.id);
    if (currentGoal != null && mounted) {
      setState(() {
        _selectedGoal = currentGoal.goalType;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength(String value) {
    double strength = 0.0;
    Color color = Colors.red;
    if (value.isNotEmpty) {
      if (value.length >= 8) strength += 0.25;
      if (RegExp(r'[A-Z]').hasMatch(value)) strength += 0.25;
      if (RegExp(r'[0-9]').hasMatch(value)) strength += 0.25;
      if (RegExp(r'[!@#$&*~%^\-+=_.,?]').hasMatch(value)) strength += 0.25;

      if (strength < 0.5) color = Colors.red;
      else if (strength < 1.0) color = Colors.orange;
      else color = Colors.green;
    }
    setState(() {
      _passwordStrength = strength;
      _passwordStrengthColor = color;
    });
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() { _isChangingPassword = true; });
    try {
      await widget.authService.changePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre mot de passe a été modifié avec succès'), backgroundColor: Colors.green),
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() { _passwordStrength = 0.0; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final currentUser = widget.authService.currentUser!;
      
      final newHeight = double.parse(_heightController.text);
      final newWeight = double.parse(_weightController.text);

      final updatedUser = currentUser.copyWith(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        heightCm: newHeight,
        initialWeightKg: newWeight,
        activityLevel: _selectedActivity,
      );

      // Recalculer les objectifs avec la logique métier
      final newGoal = widget.authService.calculateGoals(updatedUser, _selectedGoal);

      await _userRepo.updateUserAndGoals(updatedUser, newGoal);
      
      // Mettre à jour la session en mémoire
      await widget.authService.initializeSession(); 

      if (!mounted) return;
      Navigator.of(context).pop(true); // Return true to signal a refresh is needed
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.5))),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ),
                
              const Text('Informations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'Prénom'),
                validator: (val) => val!.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (val) => val!.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 24),

              const Text('Données Physiques', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Taille (cm)'),
                      validator: (val) => (val == null || double.tryParse(val) == null) ? 'Invalide' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Poids (kg)'),
                      validator: (val) => (val == null || double.tryParse(val) == null) ? 'Invalide' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text('Activité & Objectif', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedActivity,
                decoration: const InputDecoration(labelText: 'Niveau d\'activité'),
                items: const [
                  DropdownMenuItem(value: 'sedentary', child: Text('Sédentaire')),
                  DropdownMenuItem(value: 'light', child: Text('Léger')),
                  DropdownMenuItem(value: 'moderate', child: Text('Modéré')),
                  DropdownMenuItem(value: 'intense', child: Text('Intense')),
                ],
                onChanged: (val) => setState(() => _selectedActivity = val!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGoal,
                decoration: const InputDecoration(labelText: 'Objectif'),
                items: const [
                  DropdownMenuItem(value: 'weight_loss', child: Text('Perte de poids')),
                  DropdownMenuItem(value: 'maintenance', child: Text('Maintien du poids')),
                  DropdownMenuItem(value: 'weight_gain', child: Text('Prise de poids')),
                ],
                onChanged: (val) => setState(() => _selectedGoal = val!),
              ),
              
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isLoading ? null : _saveChanges,
                child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Text('Enregistrer les modifications'),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),
              const Text('Sécurité du compte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Form(
                key: _passwordFormKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe actuel',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureCurrent ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        ),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Requis' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      onChanged: _updatePasswordStrength,
                      decoration: InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        prefixIcon: const Icon(Icons.lock_reset),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNew ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      validator: (val) {
                        if (val == _currentPasswordController.text) return 'Doit être différent de l\'actuel';
                        return Validators.validatePassword(val);
                      },
                    ),
                    const SizedBox(height: 8),
                    if (_newPasswordController.text.isNotEmpty)
                      LinearProgressIndicator(
                        value: _passwordStrength,
                        backgroundColor: Colors.grey.withValues(alpha: 0.3),
                        color: _passwordStrengthColor,
                        minHeight: 4,
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirmer le nouveau',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (val) => Validators.validateConfirmPassword(val, _newPasswordController.text),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isChangingPassword ? null : _changePassword,
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      child: _isChangingPassword 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
                        : const Text('Modifier le mot de passe'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}