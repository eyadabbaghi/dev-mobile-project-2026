/// Réactions disponibles sur les publications et les commentaires.
enum CommunityReaction {
  like('like', 'J’aime', '👍'),
  love('love', 'J’adore', '❤️'),
  haha('haha', 'Haha', '😂'),
  wow('wow', 'Wow', '😮'),
  sad('sad', 'Triste', '😢'),
  angry('angry', 'En colère', '😠');

  const CommunityReaction(this.storageValue, this.label, this.emoji);

  final String storageValue;
  final String label;
  final String emoji;

  static CommunityReaction? fromStorage(String? value) {
    if (value == null) return null;
    for (final reaction in CommunityReaction.values) {
      if (reaction.storageValue == value) return reaction;
    }
    return null;
  }
}

class ReactionEntry {
  const ReactionEntry({
    required this.userId,
    required this.userName,
    required this.reaction,
  });

  final String userId;
  final String userName;
  final CommunityReaction reaction;
}

class ReactionSummary {
  const ReactionSummary({
    this.counts = const {},
    this.myReaction,
  });

  final Map<CommunityReaction, int> counts;
  final CommunityReaction? myReaction;

  int get total => counts.values.fold(0, (sum, count) => sum + count);

  int countOf(CommunityReaction reaction) => counts[reaction] ?? 0;
}
