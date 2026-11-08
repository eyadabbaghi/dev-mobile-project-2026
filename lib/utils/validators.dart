class Validators {
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Ce champ est requis.';
    if (value.trim().length < 2) return 'Minimum 2 caractères.';
    if (!RegExp(r'^[a-zA-ZÀ-ÿ\s\-]+$').hasMatch(value)) return 'Uniquement des lettres.';
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'L\'email est requis.';
    final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) return 'Format d\'email invalide.';
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Le mot de passe est requis.';
    if (value.length < 8) return 'Minimum 8 caractères.';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Au moins une majuscule.';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Au moins une minuscule.';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Au moins un chiffre.';
    if (!RegExp(r'[!@#$&*~%^\-+=_.,?]').hasMatch(value)) {
      return 'Au moins un caractère spécial.';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Veuillez confirmer le mot de passe.';
    if (value != password) return 'Les mots de passe ne correspondent pas.';
    return null;
  }

  static String? validateHeight(String? value) {
    if (value == null || value.trim().isEmpty) return 'La taille est requise.';
    final height = double.tryParse(value.trim().replaceAll(',', '.'));
    if (height == null) return 'Valeur numérique requise.';
    if (height < 100 || height > 250) return 'Taille entre 100 et 250 cm.';
    return null;
  }

  static String? validateWeight(String? value) {
    if (value == null || value.trim().isEmpty) return 'Le poids est requis.';
    final weight = double.tryParse(value.trim().replaceAll(',', '.'));
    if (weight == null) return 'Valeur numérique requise.';
    if (weight < 20 || weight > 350) return 'Poids entre 20 et 350 kg.';
    return null;
  }

  static String? validateTargetWeight(String? value, String goalType, double? currentWeight) {
    if (goalType == 'maintenance') return null;
    if (value == null || value.trim().isEmpty) return 'Le poids cible est requis.';
    final target = double.tryParse(value.trim().replaceAll(',', '.'));
    if (target == null) return 'Valeur numérique requise.';
    if (target < 20 || target > 350) return 'Poids entre 20 et 350 kg.';
    if (currentWeight != null) {
      if (goalType == 'weight_loss' && target >= currentWeight) {
        return 'Doit être inférieur au poids actuel.';
      }
      if (goalType == 'weight_gain' && target <= currentWeight) {
        return 'Doit être supérieur au poids actuel.';
      }
    }
    return null;
  }
}