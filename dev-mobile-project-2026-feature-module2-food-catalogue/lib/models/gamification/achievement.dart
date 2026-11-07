class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final int xpReward;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.xpReward,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  factory Achievement.fromDatabaseMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      iconName: map['icon_name'] as String,
      xpReward: map['xp_reward'] as int,
      isUnlocked: map.containsKey('unlocked_at') && map['unlocked_at'] != null,
      unlockedAt: map['unlocked_at'] != null ? DateTime.parse(map['unlocked_at'] as String) : null,
    );
  }
}
