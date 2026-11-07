import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../dashboard/main_dashboard_screen.dart';
import '../../widgets/profile_avatar.dart';

class OnboardingScreen extends StatefulWidget {
  final AuthService authService;
  const OnboardingScreen({super.key, required this.authService});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  int _currentIndex = 0;

  String? _profilePicturePath;
  DateTime? _selectedDate;
  String _selectedGender = 'M';
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String _selectedActivity = 'moderate';
  String _selectedGoal = 'maintenance';
  final _targetWeightController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  void _nextPage() {
    if (_currentIndex == 0) {
      if (!_step1FormKey.currentState!.validate()) return;
      if (_selectedDate == null) {
        setState(() => _errorMessage = "Veuillez entrer votre date de naissance.");
        return;
      }
    } else if (_currentIndex == 1) {
      if (!_step2FormKey.currentState!.validate()) return;
    }
    setState(() => _errorMessage = null);
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _previousPage() {
    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _complete() async {
    if (!_step3FormKey.currentState!.validate()) return;
    
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final customTargetWeight = _selectedGoal != 'maintenance' && _targetWeightController.text.isNotEmpty 
          ? double.tryParse(_targetWeightController.text.replaceAll(',', '.')) 
          : null;

      await widget.authService.completeOnboarding(
        birthDate: _selectedDate!,
        gender: _selectedGender,
        heightCm: double.parse(_heightController.text.replaceAll(',', '.')),
        initialWeightKg: double.parse(_weightController.text.replaceAll(',', '.')),
        activityLevel: _selectedActivity,
        goalType: _selectedGoal,
        profilePicturePath: _profilePicturePath,
        customTargetWeight: customTargetWeight,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => MainDashboardScreen(authService: widget.authService)),
        (route) => false,
      );
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
      appBar: AppBar(title: const Text('Profil & Objectifs'), automaticallyImplyLeading: false),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_currentIndex + 1) / 3, color: Theme.of(context).colorScheme.primary),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentIndex > 0)
                  OutlinedButton(onPressed: _previousPage, child: const Text('Précédent'))
                else
                  const SizedBox.shrink(),
                if (_currentIndex < 2)
                  FilledButton(onPressed: _nextPage, child: const Text('Suivant'))
                else
                  FilledButton(
                    onPressed: _isLoading ? null : _complete,
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('Terminer'),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _step1FormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Étape 1 sur 3', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Mieux vous connaître', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            
            Center(
              child: ProfileAvatar(
                imagePath: _profilePicturePath,
                userId: widget.authService.currentUser!.id,
                onImageChanged: (path) => setState(() => _profilePicturePath = path),
              ),
            ),
            const SizedBox(height: 32),

            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context, 
                  initialDate: DateTime.now().subtract(const Duration(days: 365*20)), 
                  firstDate: DateTime(1900), 
                  lastDate: DateTime.now()
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(_selectedDate == null ? 'Sélectionner la date de naissance' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
            ),
            if (_selectedDate == null && _errorMessage == "Veuillez entrer votre date de naissance.")
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('La date de naissance est requise.', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(labelText: 'Sexe'),
              items: const [
                DropdownMenuItem(value: 'M', child: Text('Homme')),
                DropdownMenuItem(value: 'F', child: Text('Femme')),
              ],
              onChanged: (val) => setState(() => _selectedGender = val!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _step2FormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Étape 2 sur 3', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Physique & Activité', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Taille (cm)'),
                    validator: Validators.validateHeight,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Poids (kg)'),
                    validator: Validators.validateWeight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selectedActivity,
              decoration: const InputDecoration(labelText: 'Niveau d\'activité'),
              items: const [
                DropdownMenuItem(value: 'sedentary', child: Text('Sédentaire')),
                DropdownMenuItem(value: 'light', child: Text('Léger (1-3 jours/sem)')),
                DropdownMenuItem(value: 'moderate', child: Text('Modéré (3-5 jours/sem)')),
                DropdownMenuItem(value: 'intense', child: Text('Intense (6-7 jours/sem)')),
              ],
              onChanged: (val) => setState(() => _selectedActivity = val!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _step3FormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Étape 3 sur 3', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Vos objectifs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            DropdownButtonFormField<String>(
              value: _selectedGoal,
              decoration: const InputDecoration(labelText: 'Quel est votre but ?'),
              items: const [
                DropdownMenuItem(value: 'weight_loss', child: Text('Perte de poids')),
                DropdownMenuItem(value: 'maintenance', child: Text('Maintien du poids')),
                DropdownMenuItem(value: 'weight_gain', child: Text('Prise de poids')),
              ],
              onChanged: (val) => setState(() => _selectedGoal = val!),
            ),
            if (_selectedGoal != 'maintenance') ...[
              const SizedBox(height: 24),
              TextFormField(
                controller: _targetWeightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Poids cible (kg)'),
                validator: (val) {
                  final currentWeight = double.tryParse(_weightController.text.replaceAll(',', '.'));
                  return Validators.validateTargetWeight(val, _selectedGoal, currentWeight);
                },
              ),
            ],
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: const [
                    Icon(Icons.auto_awesome, color: Colors.amber, size: 40),
                    SizedBox(height: 16),
                    Text('FitTrack AI va générer vos macros idéales (Protéines, Glucides, Lipides) et votre BMR en fonction de votre profil grâce à la formule validée de Mifflin-St Jeor.', textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}