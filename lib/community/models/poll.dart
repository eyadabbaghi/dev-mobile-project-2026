class PollOption {
  const PollOption({
    required this.id,
    required this.pollId,
    required this.label,
    this.position = 0,
    this.voteCount = 0,
    this.votedByMe = false,
  });

  final String id;
  final String pollId;
  final String label;
  final int position;
  final int voteCount;
  final bool votedByMe;
}

class PostPoll {
  const PostPoll({
    required this.id,
    required this.postId,
    required this.question,
    required this.options,
    this.endsAt,
    this.myOptionId,
  });

  final String id;
  final String postId;
  final String question;
  final List<PollOption> options;
  final DateTime? endsAt;
  final String? myOptionId;

  int get totalVotes =>
      options.fold(0, (sum, option) => sum + option.voteCount);

  bool get hasVoted => myOptionId != null;

  bool get isClosed {
    final end = endsAt;
    return end != null && DateTime.now().isAfter(end);
  }

  double percentageFor(PollOption option) {
    final total = totalVotes;
    if (total == 0) return 0;
    return option.voteCount / total;
  }
}
