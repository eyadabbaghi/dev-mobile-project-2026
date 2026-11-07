class AiRecommendation {
  final int? id;
  final String userId;
  final String title;
  final String description;
  final String category; // 'nutrition', 'tracking', 'goal'
  final String priority; // 'high', 'medium', 'low'
  final bool isRead;
  final DateTime createdAt;

  const AiRecommendation({
    this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.isRead,
    required this.createdAt,
  });

  Map<String, dynamic> toDatabaseMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AiRecommendation.fromDatabaseMap(Map<String, dynamic> map) {
    return AiRecommendation(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String,
      priority: map['priority'] as String,
      isRead: (map['is_read'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}