/// Origine d'un résultat produit par le module IA.
enum AiSource {
  gemini('Gemini'),
  local('IA locale');

  const AiSource(this.label);

  final String label;

  static AiSource fromStorage(String? value) {
    for (final source in AiSource.values) {
      if (source.name == value) return source;
    }
    return AiSource.local;
  }
}

enum CommentSentiment {
  positive('Positif'),
  negative('Négatif'),
  neutral('Neutre');

  const CommentSentiment(this.label);

  final String label;

  static CommentSentiment fromStorage(String? value) {
    for (final sentiment in CommentSentiment.values) {
      if (sentiment.name == value) return sentiment;
    }
    return CommentSentiment.neutral;
  }
}

class SentimentResult {
  const SentimentResult({
    required this.sentiment,
    required this.source,
    this.score = 0,
    this.explanation = '',
  });

  final CommentSentiment sentiment;
  final AiSource source;
  final int score;
  final String explanation;
}

class AiTextResult {
  const AiTextResult({
    required this.text,
    required this.source,
    this.hashtags = const [],
    this.note,
  });

  final String text;
  final AiSource source;
  final List<String> hashtags;
  final String? note;
}

class AiReplySuggestion {
  const AiReplySuggestion({
    required this.tone,
    required this.text,
  });

  final String tone;
  final String text;
}

class AiModerationResult {
  const AiModerationResult({
    required this.isFlagged,
    required this.source,
    this.categories = const [],
    this.explanation = '',
  });

  final bool isFlagged;
  final AiSource source;
  final List<String> categories;
  final String explanation;

  String get summary => categories.isEmpty
      ? explanation
      : '${categories.join(' · ')}${explanation.isEmpty ? '' : ' — $explanation'}';
}

class AiSpamResult {
  const AiSpamResult({
    required this.isSpam,
    required this.source,
    this.reason = '',
  });

  final bool isSpam;
  final AiSource source;
  final String reason;
}

class DiscussionSummary {
  const DiscussionSummary({
    required this.summary,
    required this.source,
    this.mainOpinions = const [],
    this.frequentlyAskedQuestions = const [],
    this.highlights = const [],
  });

  final String summary;
  final AiSource source;
  final List<String> mainOpinions;
  final List<String> frequentlyAskedQuestions;
  final List<String> highlights;
}

enum CommunityLanguage {
  french('fr', 'Français'),
  english('en', 'English'),
  arabic('ar', 'العربية');

  const CommunityLanguage(this.code, this.label);

  final String code;
  final String label;

  static CommunityLanguage fromCode(String? code) {
    for (final language in CommunityLanguage.values) {
      if (language.code == code) return language;
    }
    return CommunityLanguage.french;
  }
}
