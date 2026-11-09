import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/comment_insights.dart';
import '../models/community_notification.dart';
import '../models/community_reaction.dart';
import '../models/post.dart';

extension PostThemeStyle on PostTheme {
  IconData get icon => switch (this) {
    PostTheme.meal => Icons.restaurant_rounded,
    PostTheme.nutrition => Icons.eco_rounded,
    PostTheme.sport => Icons.fitness_center_rounded,
    PostTheme.progress => Icons.trending_up_rounded,
  };

  Color get color => switch (this) {
    PostTheme.meal => const Color(0xFFFFA24C),
    PostTheme.nutrition => const Color(0xFF8BD17C),
    PostTheme.sport => const Color(0xFF6FB6FF),
    PostTheme.progress => const Color(0xFFC59CFF),
  };
}

extension CommunityReactionStyle on CommunityReaction {
  Color get color => switch (this) {
    CommunityReaction.like => const Color(0xFF6FB6FF),
    CommunityReaction.love => const Color(0xFFFF6B81),
    CommunityReaction.haha => const Color(0xFFFFC857),
    CommunityReaction.wow => const Color(0xFFFFA24C),
    CommunityReaction.sad => const Color(0xFF8EA4C8),
    CommunityReaction.angry => const Color(0xFFFF7A5C),
  };
}

extension CommentSentimentStyle on CommentSentiment {
  IconData get icon => switch (this) {
    CommentSentiment.positive => Icons.sentiment_satisfied_alt_rounded,
    CommentSentiment.negative => Icons.sentiment_dissatisfied_rounded,
    CommentSentiment.neutral => Icons.sentiment_neutral_rounded,
  };

  Color get color => switch (this) {
    CommentSentiment.positive => const Color(0xFF8BD17C),
    CommentSentiment.negative => const Color(0xFFFF8A80),
    CommentSentiment.neutral => const Color(0xFF9AA39A),
  };
}

extension CommunityNotificationStyle on CommunityNotificationType {
  IconData get icon => switch (this) {
    CommunityNotificationType.reaction => Icons.favorite_rounded,
    CommunityNotificationType.comment => Icons.chat_bubble_rounded,
    CommunityNotificationType.reply => Icons.reply_rounded,
    CommunityNotificationType.mention => Icons.alternate_email_rounded,
    CommunityNotificationType.commentReaction => Icons.emoji_emotions_rounded,
    CommunityNotificationType.pollActivity => Icons.poll_rounded,
    CommunityNotificationType.pollClosed => Icons.how_to_vote_rounded,
  };
}

String formatPostTime(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inSeconds < 60) return "À l'instant";
  if (difference.inMinutes < 60) {
    return 'Il y a ${difference.inMinutes} min';
  }
  if (difference.inHours < 24 &&
      now.year == date.year &&
      now.month == date.month &&
      now.day == date.day) {
    return 'Il y a ${difference.inHours} h';
  }

  final yesterday = now.subtract(const Duration(days: 1));
  if (date.year == yesterday.year &&
      date.month == yesterday.month &&
      date.day == yesterday.day) {
    return 'Hier';
  }

  return DateFormat('dd/MM/yyyy').format(date);
}

String formatPollEnd(DateTime date) {
  final difference = date.difference(DateTime.now());
  if (difference.isNegative) return 'Sondage terminé';
  if (difference.inHours < 1) {
    return 'Se termine dans ${difference.inMinutes} min';
  }
  if (difference.inDays < 1) {
    return 'Se termine dans ${difference.inHours} h';
  }
  return 'Se termine ${DateFormat('dd/MM à HH:mm').format(date)}';
}

String initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

/// Extrait les hashtags sans le caractère `#`.
List<String> extractHashtags(String text) {
  final matches = RegExp(
    r'#([^\s#.,!?;:()\[\]{}]+)',
    unicode: true,
  ).allMatches(text);
  final tags = <String>[];
  for (final match in matches) {
    final tag = match.group(1)?.trim();
    if (tag != null && tag.isNotEmpty && !tags.contains(tag)) {
      tags.add(tag);
    }
  }
  return tags;
}

/// Extrait les @mentions sans le caractère `@`.
List<String> extractMentions(String text) {
  final matches = RegExp(
    r'@([A-Za-z0-9_.]+)',
    unicode: true,
  ).allMatches(text);
  final mentions = <String>[];
  for (final match in matches) {
    final mention = match.group(1)?.trim();
    if (mention != null && mention.isNotEmpty && !mentions.contains(mention)) {
      mentions.add(mention);
    }
  }
  return mentions;
}

String normalizeUsername(String name) {
  final normalized = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return normalized.isEmpty ? 'membre' : normalized;
}

String formatReactionList(Map<CommunityReaction, int> counts) {
  return CommunityReaction.values
      .where((reaction) => (counts[reaction] ?? 0) > 0)
      .map((reaction) => '${reaction.emoji} ${counts[reaction]}')
      .join('  ');
}

String truncateText(String text, int maxLength) {
  final trimmed = text.trim();
  if (trimmed.length <= maxLength) return trimmed;
  return '${trimmed.substring(0, maxLength - 1).trimRight()}…';
}
