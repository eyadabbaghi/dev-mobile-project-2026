class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String passwordHash;
  final DateTime? birthDate;
  final String? gender;
  final double? heightCm;
  final double? initialWeightKg;
  final String? activityLevel;
  final String? profilePicturePath;
  final bool isOnboarded;
  final bool isCoach;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.passwordHash,
    this.birthDate,
    this.gender,
    this.heightCm,
    this.initialWeightKg,
    this.activityLevel,
    this.profilePicturePath,
    required this.isOnboarded,
    this.isCoach = false,
    required this.createdAt,
  });

  int get age {
    if (birthDate == null) return 0;
    final today = DateTime.now();
    int age = today.year - birthDate!.year;
    if (today.month < birthDate!.month ||
        (today.month == birthDate!.month && today.day < birthDate!.day)) {
      age--;
    }
    return age;
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password_hash': passwordHash,
      if (birthDate != null) 'birth_date': birthDate!.toIso8601String(),
      if (gender != null) 'gender': gender,
      if (heightCm != null) 'height_cm': heightCm,
      if (initialWeightKg != null) 'initial_weight_kg': initialWeightKg,
      if (activityLevel != null) 'activity_level': activityLevel,
      if (profilePicturePath != null)
        'profile_picture_path': profilePicturePath,
      'is_onboarded': isOnboarded ? 1 : 0,
      'is_coach': isCoach ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory User.fromDatabaseMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      email: map['email'] as String,
      passwordHash: map['password_hash'] as String,
      birthDate: map['birth_date'] != null
          ? DateTime.parse(map['birth_date'] as String)
          : null,
      gender: map['gender'] as String?,
      heightCm: map['height_cm'] != null
          ? (map['height_cm'] as num).toDouble()
          : null,
      initialWeightKg: map['initial_weight_kg'] != null
          ? (map['initial_weight_kg'] as num).toDouble()
          : null,
      activityLevel: map['activity_level'] as String?,
      profilePicturePath: map['profile_picture_path'] as String?,
      isOnboarded: (map['is_onboarded'] as int) == 1,
      isCoach: (map['is_coach'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  User copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? passwordHash,
    DateTime? birthDate,
    String? gender,
    double? heightCm,
    double? initialWeightKg,
    String? activityLevel,
    String? profilePicturePath,
    bool clearProfilePicture = false,
    bool? isOnboarded,
    bool? isCoach,
  }) {
    return User(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      initialWeightKg: initialWeightKg ?? this.initialWeightKg,
      activityLevel: activityLevel ?? this.activityLevel,
      profilePicturePath: clearProfilePicture
          ? null
          : (profilePicturePath ?? this.profilePicturePath),
      isOnboarded: isOnboarded ?? this.isOnboarded,
      isCoach: isCoach ?? this.isCoach,
      createdAt: createdAt,
    );
  }
}
