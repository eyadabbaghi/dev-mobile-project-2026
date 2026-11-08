import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/user.dart';
import '../models/user_goal.dart';
import '../models/weight_entry.dart';
import '../repositories/user_repository.dart';

class AuthService {
  final UserRepository _userRepository = UserRepository();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final Uuid _uuid = const Uuid();

  static const String _sessionKey = 'fittrack_session_user_id';

  User? _currentUser;
  User? get currentUser => _currentUser;

  Future<void> initializeSession() async {
    final userId = await _secureStorage.read(key: _sessionKey);
    if (userId != null) {
      _currentUser = await _userRepository.getUserById(userId);
    }
  }

  String _hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  bool _verifyPassword(String password, String hashed) {
    if (hashed.startsWith(r'$2')) {
      return BCrypt.checkpw(password, hashed);
    } else {
      // Compatibilité pour l'ancien hash SHA-256
      final bytes = utf8.encode(password);
      final digest = sha256.convert(bytes);
      return digest.toString() == hashed;
    }
  }

  Future<User?> login(String email, String password) async {
    final user = await _userRepository.getUserByEmail(email.trim());
    if (user == null) {
      throw Exception('Aucun compte trouvé avec cet email.');
    }
    
    if (!_verifyPassword(password, user.passwordHash)) {
      throw Exception('Mot de passe incorrect.');
    }

    _currentUser = user;
    await _secureStorage.write(key: _sessionKey, value: user.id);
    return user;
  }

  Future<User> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final existingUser = await _userRepository.getUserByEmail(email.trim());
    if (existingUser != null) {
      throw Exception('Un compte existe déjà avec cet email.');
    }

    final user = User(
      id: _uuid.v4(),
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      email: email.trim().toLowerCase(),
      passwordHash: _hashPassword(password),
      isOnboarded: false, // Onboarding required
      createdAt: DateTime.now(),
    );

    await _userRepository.createUserOnly(user);
    
    _currentUser = user;
    await _secureStorage.write(key: _sessionKey, value: user.id);
    return user;
  }

  Future<User> completeOnboarding({
    required DateTime birthDate,
    required String gender,
    required double heightCm,
    required double initialWeightKg,
    required String activityLevel,
    required String goalType,
    String? profilePicturePath,
    double? customTargetWeight,
  }) async {
    if (_currentUser == null) throw Exception('Utilisateur non connecté.');

    final updatedUser = _currentUser!.copyWith(
      birthDate: birthDate,
      gender: gender,
      heightCm: heightCm,
      initialWeightKg: initialWeightKg,
      activityLevel: activityLevel,
      isOnboarded: true,
      profilePicturePath: profilePicturePath,
    );

    // Calcul Automatique du BMR (Mifflin-St Jeor)
    final goal = calculateGoals(updatedUser, goalType, customTargetWeight);

    await _userRepository.updateUserAndGoals(updatedUser, goal);
    
    // Add initial weight to history
    await _userRepository.addOrUpdateWeight(WeightEntry(
      userId: updatedUser.id,
      weightKg: initialWeightKg,
      date: DateTime.now(),
    ));
    
    _currentUser = updatedUser;
    return updatedUser;
  }

  Future<void> logout() async {
    _currentUser = null;
    await _secureStorage.delete(key: _sessionKey);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    if (_currentUser == null) throw Exception('Utilisateur non connecté.');
    
    if (!_verifyPassword(currentPassword, _currentUser!.passwordHash)) {
      throw Exception('Le mot de passe actuel est incorrect.');
    }
    
    final updatedUser = _currentUser!.copyWith(
      passwordHash: _hashPassword(newPassword),
    );
    
    await _userRepository.updateUser(updatedUser);
    _currentUser = updatedUser;
  }

  // --- BIOMETRICS ---
  static const String _biometricUserIdKey = 'fittrack_biometric_user_id';

  Future<bool> canUseBiometrics() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) return false;
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;
      final biometrics = await _localAuth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isBiometricEnabledForAnyUser() async {
    final storedUserId = await _secureStorage.read(key: _biometricUserIdKey);
    return storedUserId != null;
  }

  Future<bool> isBiometricEnabledForCurrentUser() async {
    if (_currentUser == null) return false;
    final storedUserId = await _secureStorage.read(key: _biometricUserIdKey);
    return storedUserId == _currentUser!.id;
  }

  Future<void> _checkBiometricPrerequisites() async {
    final isSupported = await _localAuth.isDeviceSupported();
    if (!isSupported) {
      throw Exception("Cet appareil ne supporte pas la biométrie (Face ID / Touch ID).");
    }

    final canCheck = await _localAuth.canCheckBiometrics;
    final availableBiometrics = await _localAuth.getAvailableBiometrics();

    if (!canCheck || availableBiometrics.isEmpty) {
      throw Exception(
        "Aucune donnée biométrique n'est configurée.\n\n"
        "Veuillez configurer un code de verrouillage (PIN/Mot de passe) "
        "et enregistrer votre visage ou empreinte dans les paramètres de votre appareil."
      );
    }
  }

  Future<void> enableBiometricLogin() async {
    if (_currentUser == null) throw Exception('Utilisateur non connecté.');
    
    await _checkBiometricPrerequisites();

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Confirmez votre identité pour activer la connexion biométrique',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        await _secureStorage.write(key: _biometricUserIdKey, value: _currentUser!.id);
      } else {
        throw Exception('Authentification annulée ou échouée.');
      }
    } catch (e) {
      final eStr = e.toString();
      if (eStr.contains('noCredentialsSet') || eStr.contains('NotEnrolled') || eStr.contains('PasscodeNotSet')) {
        throw Exception(
          "Veuillez configurer un verrouillage d'écran et la biométrie dans les paramètres de votre appareil."
        );
      }
      rethrow;
    }
  }

  Future<void> disableBiometricLogin() async {
    await _secureStorage.delete(key: _biometricUserIdKey);
  }

  Future<User?> loginWithBiometrics() async {
    final storedUserId = await _secureStorage.read(key: _biometricUserIdKey);
    if (storedUserId == null) throw Exception('La biométrie n\'est pas activée.');

    await _checkBiometricPrerequisites();

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Veuillez vous authentifier pour accéder à FitTrack AI',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        final user = await _userRepository.getUserById(storedUserId);
        if (user == null) {
          await disableBiometricLogin();
          throw Exception('Compte introuvable. Veuillez vous reconnecter manuellement.');
        }
        _currentUser = user;
        await _secureStorage.write(key: _sessionKey, value: user.id);
        return user;
      } else {
        throw Exception('Échec de l\'authentification biométrique.');
      }
    } catch (e) {
      final eStr = e.toString();
      if (eStr.contains('noCredentialsSet') || eStr.contains('NotEnrolled') || eStr.contains('PasscodeNotSet')) {
        throw Exception(
          "Veuillez configurer un verrouillage d'écran et la biométrie dans les paramètres de votre appareil."
        );
      }
      rethrow;
    }
  }

  // --- GOALS CALCULATION ---
  UserGoal calculateGoals(User user, String goalType, [double? customTargetWeight]) {
    if (user.initialWeightKg == null || user.heightCm == null || user.birthDate == null || user.gender == null) {
      throw Exception("Données utilisateur manquantes pour le calcul.");
    }
    // Mifflin-St Jeor
    double bmr = (10 * user.initialWeightKg!) + (6.25 * user.heightCm!) - (5 * user.age);
    if (user.gender!.toUpperCase() == 'M') {
      bmr += 5;
    } else {
      bmr -= 161;
    }

    // Facteur d'activité
    double activityFactor = 1.2;
    switch (user.activityLevel?.toLowerCase()) {
      case 'light': activityFactor = 1.375; break;
      case 'moderate': activityFactor = 1.55; break;
      case 'intense': activityFactor = 1.725; break;
    }

    double tdee = bmr * activityFactor;
    int dailyCalories = tdee.round();

    double targetWeight = user.initialWeightKg!;
    if (goalType == 'weight_loss') {
      dailyCalories -= 500;
      targetWeight = customTargetWeight ?? (targetWeight - 5.0);
    } else if (goalType == 'weight_gain') {
      dailyCalories += 500;
      targetWeight = customTargetWeight ?? (targetWeight + 5.0);
    }

    int proteinGrams = ((dailyCalories * 0.30) / 4).round();
    int carbsGrams = ((dailyCalories * 0.40) / 4).round();
    int fatGrams = ((dailyCalories * 0.30) / 9).round();
    int dailyWaterMl = (user.initialWeightKg! * 35).round();

    return UserGoal(
      userId: user.id,
      goalType: goalType,
      targetWeightKg: targetWeight,
      dailyCalories: dailyCalories,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      dailyWaterMl: dailyWaterMl,
      isManual: false,
    );
  }
}
