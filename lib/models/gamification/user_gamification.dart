class UserGamification {
  final String userId;
  final int xp;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActionDate;

  const UserGamification({
    required this.userId,
    required this.xp,
    required this.level,
    required this.currentStreak,
    required this.longestStreak,
    this.lastActionDate,
  });

  Map<String, dynamic> toDatabaseMap() {
    return {
      'user_id': userId,
      'xp': xp,
      'level': level,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      if (lastActionDate != null) 'last_action_date': "${lastActionDate!.year.toString().padLeft(4, '0')}-${lastActionDate!.month.toString().padLeft(2, '0')}-${lastActionDate!.day.toString().padLeft(2, '0')}",
    };
  }

  factory UserGamification.fromDatabaseMap(Map<String, dynamic> map) {
    return UserGamification(
      userId: map['user_id'] as String,
      xp: map['xp'] as int,
      level: map['level'] as int,
      currentStreak: map['current_streak'] as int,
      longestStreak: map['longest_streak'] as int,
      lastActionDate: map['last_action_date'] != null ? DateTime.parse(map['last_action_date'] as String) : null,
    );
  }

  UserGamification copyWith({
    int? xp,
    int? level,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActionDate,
  }) {
    return UserGamification(
      userId: userId,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActionDate: lastActionDate ?? this.lastActionDate,
    );
  }
}
