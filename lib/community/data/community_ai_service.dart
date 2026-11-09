import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/comment_insights.dart';
import '../models/post_comment.dart';

class CommunityAiException implements Exception {
  const CommunityAiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Services IA du module Publications & Commentaires.
///
/// - Utilise Gemini si `GEMINI_API_KEY` est fourni via `--dart-define` ou
///   `env.json` (aucune clé n'est écrite dans le code).
/// - Fournit un moteur local de secours pour que les fonctionnalités restent
///   testables hors ligne. La source est toujours affichée dans l'interface.
class CommunityAiService {
  CommunityAiService({
    String? apiKey,
    http.Client? client,
  }) : _providedKey = apiKey,
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  static const model = 'gemini-3.6-flash';
  static const _timeout = Duration(seconds: 18);

  static const List<String> publicationActions = [
    'generate',
    'rewrite',
    'correct',
    'hashtags',
  ];

  static const List<String> writingTones = [
    'amical',
    'professionnel',
    'humour',
    'motivant',
  ];

  final String? _providedKey;
  final http.Client _client;
  final bool _ownsClient;
  String? _cachedKey;

  Future<String> _resolveApiKey() async {
    if (_cachedKey != null) return _cachedKey!;
    final provided = _providedKey?.trim() ?? '';
    if (provided.isNotEmpty) return _cachedKey = provided;

    const fromEnvironment = String.fromEnvironment('GEMINI_API_KEY');
    if (fromEnvironment.trim().isNotEmpty) {
      return _cachedKey = fromEnvironment.trim();
    }

    try {
      final raw = await rootBundle.loadString('env.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final key = decoded['GEMINI_API_KEY']?.toString().trim() ?? '';
        if (key.isNotEmpty) return _cachedKey = key;
      }
    } catch (_) {
      // Pas de env.json accessible : le moteur local prend le relais.
    }
    return _cachedKey = '';
  }

  Future<bool> isConfigured() async => (await _resolveApiKey()).isNotEmpty;

  /// A. Générateur de publication.
  Future<AiTextResult> generatePublication({
    required String prompt,
    String action = 'generate',
    String tone = 'amical',
    String currentText = '',
    String theme = '',
  }) async {
    final key = await _resolveApiKey();
    String? note;
    if (key.isNotEmpty) {
      try {
        final actionLabel = switch (action) {
          'rewrite' => 'Réécris et améliore',
          'correct' => 'Corrige l’orthographe et la grammaire de',
          'hashtags' => 'Propose des hashtags pertinents pour',
          _ => 'Génère une publication courte et engageante à partir de',
        };
        final json = await _generateJson(
          '''
Tu es l'assistant de rédaction du module Publications d'une application fitness.
$actionLabel ce contenu :
"""${currentText.trim().isEmpty ? prompt.trim() : currentText.trim()}"""
Ton demandé : $tone.
Thème : ${theme.isEmpty ? 'non précisé' : theme}.
Réponds uniquement en JSON :
{"text":"texte final sans hashtags","hashtags":["#exemple"]}
Le texte doit rester en français, sans inventer de faits personnels.
''',
          temperature: 0.7,
          maxTokens: 700,
        );
        final text = _cleanText(json['text']?.toString() ?? '');
        final hashtags = _stringList(json['hashtags']);
        if (text.isNotEmpty) {
          return AiTextResult(
            text: action == 'hashtags' && currentText.isNotEmpty
                ? currentText.trim()
                : text,
            hashtags: hashtags,
            source: AiSource.gemini,
          );
        }
      } on CommunityAiException catch (error) {
        note = error.message;
      }
    }
    return _localPublication(
      prompt: prompt,
      action: action,
      tone: tone,
      currentText: currentText,
      theme: theme,
      note: note,
    );
  }

  /// B. Suggestions de réponses à un commentaire.
  Future<List<AiReplySuggestion>> suggestReplies({
    required String postContent,
    required String commentContent,
  }) async {
    final key = await _resolveApiKey();
    if (key.isNotEmpty) {
      try {
        final json = await _generateJson(
          '''
Tu aides à répondre dans un fil de commentaires fitness.
Publication : """${_truncate(postContent, 600)}"""
Commentaire : """${_truncate(commentContent, 400)}"""
Propose exactement 3 réponses courtes en français, une amicale, une
professionnelle et une humoristique. Ne publie rien automatiquement.
Réponds uniquement en JSON :
{"replies":[{"tone":"amical","text":"..."},{"tone":"professionnel","text":"..."},{"tone":"humour","text":"..."}]}
''',
          temperature: 0.8,
          maxTokens: 500,
        );
        final raw = json['replies'];
        if (raw is List) {
          final replies = <AiReplySuggestion>[];
          for (final item in raw) {
            if (item is! Map<String, dynamic>) continue;
            final text = _cleanText(item['text']?.toString() ?? '');
            if (text.isEmpty) continue;
            replies.add(
              AiReplySuggestion(
                tone: item['tone']?.toString() ?? 'amical',
                text: text,
              ),
            );
          }
          if (replies.length >= 3) return replies.take(3).toList();
        }
      } on CommunityAiException {
        // Repli local ci-dessous.
      }
    }
    return _localReplies(
      postContent: postContent,
      commentContent: commentContent,
    );
  }

  /// C. Modération de commentaire.
  Future<AiModerationResult> moderateText(String text) async {
    final local = _localModeration(text);
    if (local.isFlagged) return local;

    final key = await _resolveApiKey();
    if (key.isEmpty) return local;
    try {
      final json = await _generateJson(
        '''
Analyse ce commentaire pour détecter insultes, harcèlement, haine, violence,
contenu explicite ou contenu potentiellement nuisible.
Commentaire : """${_truncate(text, 1500)}"""
Réponds uniquement en JSON :
{"flagged":false,"categories":[],"explanation":"courte explication en français"}
Ne propose jamais de suppression automatique.
''',
        temperature: 0.1,
        maxTokens: 300,
      );
      final flagged = json['flagged'] == true;
      return AiModerationResult(
        isFlagged: flagged,
        categories: _stringList(json['categories']),
        explanation: json['explanation']?.toString() ?? '',
        source: AiSource.gemini,
      );
    } on CommunityAiException {
      return local;
    }
  }

  /// D. Détection de spam.
  Future<AiSpamResult> detectSpam({
    required String text,
    List<String> recentComments = const [],
  }) async {
    final local = _localSpam(text: text, recentComments: recentComments);
    if (local.isSpam) return local;

    final key = await _resolveApiKey();
    if (key.isEmpty) return local;
    try {
      final json = await _generateJson(
        '''
Détecte le spam dans ce commentaire (promotion, liens suspects, répétition).
Commentaire : """${_truncate(text, 1200)}"""
Réponds uniquement en JSON :
{"spam":false,"reason":"courte explication en français"}
''',
        temperature: 0.1,
        maxTokens: 250,
      );
      return AiSpamResult(
        isSpam: json['spam'] == true,
        reason: json['reason']?.toString() ?? '',
        source: AiSource.gemini,
      );
    } on CommunityAiException {
      return local;
    }
  }

  /// E. Traduction d'un commentaire (l'original n'est jamais modifié).
  Future<AiTextResult> translate({
    required String text,
    required CommunityLanguage target,
  }) async {
    final key = await _resolveApiKey();
    if (key.isNotEmpty) {
      try {
        final json = await _generateJson(
          '''
Traduis fidèlement ce commentaire en ${target.label} sans rien ajouter.
Conserve le ton et les emojis.
Texte : """${_truncate(text, 1500)}"""
Réponds uniquement en JSON : {"translation":"..."}
''',
          temperature: 0.2,
          maxTokens: 700,
        );
        final translation = _cleanText(
          json['translation']?.toString() ?? '',
        );
        if (translation.isNotEmpty) {
          return AiTextResult(text: translation, source: AiSource.gemini);
        }
      } on CommunityAiException {
        // Repli local ci-dessous.
      }
    }
    return AiTextResult(
      text: _localTranslate(text, target),
      source: AiSource.local,
      note: 'Traduction locale approximative : configurez GEMINI_API_KEY pour '
          'une traduction complète.',
    );
  }

  /// F. Résumé de discussion.
  Future<DiscussionSummary> summarizeDiscussion({
    required String postContent,
    required List<PostComment> comments,
  }) async {
    final key = await _resolveApiKey();
    if (key.isNotEmpty && comments.isNotEmpty) {
      try {
        final payload = comments
            .take(60)
            .map(
              (comment) => {
                'author': comment.isAnonymous
                    ? 'Anonyme'
                    : comment.authorName,
                'content': _truncate(comment.content, 400),
                'sentiment': comment.sentiment?.name,
              },
            )
            .toList();
        final json = await _generateJson(
          '''
Résume cette discussion autour d'une publication fitness.
Publication : """${_truncate(postContent, 500)}"""
Commentaires JSON : ${jsonEncode(payload)}
Réponds uniquement en JSON :
{"summary":"...","opinions":["..."],"faqs":["..."],"highlights":["..."]}
Reste factuel, en français, sans inventer de messages.
''',
          temperature: 0.3,
          maxTokens: 900,
        );
        return DiscussionSummary(
          summary: _cleanText(json['summary']?.toString() ?? ''),
          mainOpinions: _stringList(json['opinions']),
          frequentlyAskedQuestions: _stringList(json['faqs']),
          highlights: _stringList(json['highlights']),
          source: AiSource.gemini,
        );
      } on CommunityAiException {
        // Repli local ci-dessous.
      }
    }
    return _localSummary(postContent: postContent, comments: comments);
  }

  /// G. Analyse de sentiment.
  Future<SentimentResult> analyzeSentiment(String text) async {
    final local = analyzeSentimentLocally(text);
    final key = await _resolveApiKey();
    if (key.isEmpty) return local;
    try {
      final json = await _generateJson(
        '''
Classe le sentiment de ce commentaire : positive, negative ou neutral.
Commentaire : """${_truncate(text, 1200)}"""
Réponds uniquement en JSON :
{"sentiment":"positive|negative|neutral","explanation":"courte justification"}
''',
        temperature: 0.1,
        maxTokens: 250,
      );
      final raw = json['sentiment']?.toString().toLowerCase();
      final sentiment = switch (raw) {
        'positive' || 'positif' => CommentSentiment.positive,
        'negative' || 'négatif' => CommentSentiment.negative,
        _ => CommentSentiment.neutral,
      };
      return SentimentResult(
        sentiment: sentiment,
        source: AiSource.gemini,
        explanation: json['explanation']?.toString() ?? '',
      );
    } on CommunityAiException {
      return local;
    }
  }

  SentimentResult analyzeSentimentLocally(String text) {
    final lower = text.toLowerCase();
    var score = 0;
    final positive = <String>[];
    final negative = <String>[];
    for (final entry in _positiveWords) {
      if (RegExp('(?<![\\p{L}])${RegExp.escape(entry)}(?![\\p{L}])', unicode: true)
          .hasMatch(lower)) {
        score += 1;
        positive.add(entry);
      }
    }
    for (final entry in _negativeWords) {
      if (RegExp('(?<![\\p{L}])${RegExp.escape(entry)}(?![\\p{L}])', unicode: true)
          .hasMatch(lower)) {
        score -= 1;
        negative.add(entry);
      }
    }
    if (lower.contains('😂') || lower.contains('😍') || lower.contains('💪')) {
      score += 1;
      positive.add('emoji positif');
    }
    if (lower.contains('😡') || lower.contains('😢')) {
      score -= 1;
      negative.add('emoji négatif');
    }

    final sentiment = score > 0
        ? CommentSentiment.positive
        : score < 0
        ? CommentSentiment.negative
        : CommentSentiment.neutral;
    final explanation = sentiment == CommentSentiment.positive
        ? 'Ton positif détecté${positive.isEmpty ? '' : ' (${positive.take(3).join(', ')})'}.'
        : sentiment == CommentSentiment.negative
        ? 'Ton négatif détecté${negative.isEmpty ? '' : ' (${negative.take(3).join(', ')})'}.'
        : 'Aucun marqueur de sentiment marqué.';
    return SentimentResult(
      sentiment: sentiment,
      source: AiSource.local,
      score: score,
      explanation: explanation,
    );
  }

  // --- MOTEUR LOCAL ---

  AiTextResult _localPublication({
    required String prompt,
    required String action,
    required String tone,
    required String currentText,
    required String theme,
    String? note,
  }) {
    final base = currentText.trim().isEmpty ? prompt.trim() : currentText.trim();
    if (action == 'hashtags') {
      return AiTextResult(
        text: base,
        hashtags: _localHashtags('$base $theme'),
        source: AiSource.local,
        note: note,
      );
    }

    final text = switch (action) {
      'rewrite' => _rewrite(base, tone),
      'correct' => _correct(base),
      _ => _generate(base, tone, theme),
    };
    return AiTextResult(
      text: text,
      hashtags: _localHashtags('$base $theme'),
      source: AiSource.local,
      note: note,
    );
  }

  String _generate(String prompt, String tone, String theme) {
    final subject = prompt.isEmpty ? 'Ma séance du jour' : prompt;
    final hook = switch (tone) {
      'professionnel' => 'Point du jour :',
      'humour' => 'Bon, on ne va pas se mentir…',
      'motivant' => 'Petite victoire du jour 💪',
      _ => 'Aujourd’hui, je partage :',
    };
    final body = _correct(subject);
    final closing = switch (tone) {
      'professionnel' =>
        'Régularité et progressivité restent les clés. Et vous, comment '
            'avancez-vous cette semaine ?',
      'humour' =>
        'Mon corps a négocié, j’ai gagné. Les courbatures sont le bonus '
            'fidélité 😅',
      'motivant' =>
        'Chaque petit pas compte. On continue, ensemble ! 🔥',
      _ => 'Si ça peut inspirer quelqu’un, je suis preneur de vos astuces 🙌',
    };
    final themeLine = theme.trim().isEmpty ? '' : '\n\n#$theme';
    return '$hook\n\n$body\n\n$closing$themeLine';
  }

  String _rewrite(String text, String tone) {
    final corrected = _correct(text);
    if (corrected.isEmpty) return corrected;
    final ending = switch (tone) {
      'professionnel' => '\n\nJe reste preneur de vos retours constructifs.',
      'humour' => '\n\nVoilà, c’était mon TED Talk du jour 😄',
      'motivant' => '\n\nUn pas après l’autre, on progresse ! 💪',
      _ => '\n\nEt vous, vous faites comment ?',
    };
    return '$corrected$ending';
  }

  String _correct(String text) {
    var result = text
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\s+([,.;!?])'), r'$1')
        .replaceAll(RegExp(r'([,.;!?])(?=\S)'), r'$1 ')
        .trim();
    if (result.isEmpty) return result;
    result = result[0].toUpperCase() + result.substring(1);
    final typos = <String, String>{
      ' je suis aller': ' je suis allé',
      ' jai ': ' j’ai ',
      ' sa va': ' ça va',
      ' cmme ': ' comme ',
      ' bcp ': ' beaucoup ',
      ' pcq ': ' parce que ',
      ' tjrs ': ' toujours ',
      ' svp ': ' s’il vous plaît ',
    };
    for (final entry in typos.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    if (!RegExp(r'[.!?…]$').hasMatch(result)) result = '$result.';
    return result;
  }

  List<String> _localHashtags(String source) {
    final words = source
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zà-ÿ0-9\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length >= 4)
        .where((word) => !_stopWords.contains(word))
        .toSet()
        .take(4)
        .map((word) => '#${word[0].toUpperCase()}${word.substring(1)}');
    final suggestions = [
      ...words,
      '#FitTrack',
      '#Communauté',
      '#Progression',
    ];
    return suggestions.toSet().take(8).toList();
  }

  List<AiReplySuggestion> _localReplies({
    required String postContent,
    required String commentContent,
  }) {
    final subject = _truncate(commentContent.trim(), 60);
    final topic = _truncate(postContent.trim(), 90);
    return [
      AiReplySuggestion(
        tone: 'amical',
        text:
            'Merci pour ton retour ! Ça fait plaisir de partager ça avec toi 🙌 '
            '${subject.isEmpty ? '' : '« $subject » me parle vraiment.'}',
      ),
      AiReplySuggestion(
        tone: 'professionnel',
        text:
            'Merci pour ce commentaire constructif. Sur « $topic », je '
            'retiens surtout la régularité et l’écoute de son corps.',
      ),
      AiReplySuggestion(
        tone: 'humour',
        text:
            'Je note, je note… mon prochain objectif : appliquer ce conseil '
            'sans négocier avec mon réveil 😅',
      ),
    ];
  }

  AiModerationResult _localModeration(String text) {
    final lower = text.toLowerCase();
    final categories = <String>{};
    final matches = <String>{};

    void scan(Map<String, List<String>> rules, String category) {
      for (final entry in rules.entries) {
        for (final pattern in entry.value) {
          final regex = RegExp(
            '(?<![\\p{L}])${RegExp.escape(pattern)}(?![\\p{L}])',
            unicode: true,
          );
          if (regex.hasMatch(lower)) {
            categories.add(category);
            matches.add(entry.key);
          }
        }
      }
    }

    scan(_insultPatterns, 'Insulte');
    scan(_harassmentPatterns, 'Harcèlement');
    scan(_hatePatterns, 'Discours haineux');
    scan(_violencePatterns, 'Violence');
    scan(_explicitPatterns, 'Contenu explicite');

    if (lower.contains('tu es') && matches.isEmpty) {
      final direct = RegExp(
        r'tu es (vraiment )?(nul|stupide|idiot|moche|inutile)',
        unicode: true,
      );
      if (direct.hasMatch(lower)) {
        categories.add('Harcèlement');
        matches.add('attaque directe');
      }
    }

    return AiModerationResult(
      isFlagged: categories.isNotEmpty,
      categories: categories.toList(),
      explanation: categories.isEmpty
          ? 'Aucun contenu problématique détecté.'
          : 'Termes détectés : ${matches.join(', ')}. Vérifiez le contexte '
                'avant de publier.',
      source: AiSource.local,
    );
  }

  AiSpamResult _localSpam({
    required String text,
    required List<String> recentComments,
  }) {
    final lower = text.toLowerCase();
    final reasons = <String>[];
    final normalized = lower.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (recentComments.any(
      (comment) =>
          comment.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim() ==
          normalized,
    )) {
      reasons.add('commentaire répété');
    }

    final linkCount = RegExp(
      r'https?:\/\/|www\.|\.com\b|\.tn\b|\.net\b',
      unicode: true,
    ).allMatches(lower).length;
    if (linkCount > 0) reasons.add('lien externe');

    final promoMatches = _spamWords.where(lower.contains).toList();
    if (promoMatches.isNotEmpty) {
      reasons.add('promotion (${promoMatches.take(3).join(', ')})');
    }

    final phoneMatches = RegExp(r'(\+?\d[\s.-]?){8,}').hasMatch(lower);
    if (phoneMatches) reasons.add('numéro de téléphone');

    final letters = text.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
    if (letters.length >= 16) {
      final upper = text.replaceAll(RegExp(r'[^A-ZÀ-Þ]'), '').length;
      if (upper / letters.length > 0.7) reasons.add('majuscules excessives');
    }

    if (RegExp(r'(.)\1{5,}').hasMatch(lower)) {
      reasons.add('répétition de caractères');
    }

    final emojiCount = RegExp(
      r'[\u{1F300}-\u{1FAFF}]',
      unicode: true,
    ).allMatches(text).length;
    if (emojiCount > 12) reasons.add('trop d’emojis');

    final spam = reasons.length >= 2 ||
        reasons.contains('commentaire répété') ||
        (reasons.contains('lien externe') && promoMatches.isNotEmpty) ||
        reasons.contains('numéro de téléphone');
    return AiSpamResult(
      isSpam: spam,
      reason: spam
          ? 'Signaux détectés : ${reasons.join(', ')}.'
          : 'Aucun signal de spam détecté.',
      source: AiSource.local,
    );
  }

  DiscussionSummary _localSummary({
    required String postContent,
    required List<PostComment> comments,
  }) {
    if (comments.isEmpty) {
      return const DiscussionSummary(
        summary: 'Aucun commentaire à résumer pour le moment.',
        source: AiSource.local,
      );
    }
    final positive = comments
        .where((comment) => comment.sentiment == CommentSentiment.positive)
        .toList();
    final negative = comments
        .where((comment) => comment.sentiment == CommentSentiment.negative)
        .toList();
    final questions = comments
        .where(
          (comment) =>
              comment.content.contains('?') ||
              RegExp(
                r'\b(comment|pourquoi|quelle|quel|est-ce|combien)\b',
                unicode: true,
                caseSensitive: false,
              ).hasMatch(comment.content),
        )
        .map((comment) => _truncate(comment.content, 160))
        .take(4)
        .toList();

    final opinions = <String>[];
    for (final comment in [...positive, ...negative, ...comments]) {
      final snippet = _truncate(comment.content, 150);
      if (snippet.isNotEmpty && !opinions.contains(snippet)) {
        opinions.add(snippet);
      }
      if (opinions.length == 3) break;
    }

    final highlights = <String>[];
    final pinned = comments.where((comment) => comment.isPinned).toList();
    final best = comments.where((comment) => comment.isBestAnswer).toList();
    for (final comment in [...pinned, ...best, ...comments]) {
      final snippet = _truncate(comment.content, 140);
      if (snippet.isNotEmpty && !highlights.contains(snippet)) {
        highlights.add(snippet);
      }
      if (highlights.length == 3) break;
    }

    final summary =
        '${comments.length} commentaire${comments.length == 1 ? '' : 's'} '
        'analysé${comments.length == 1 ? '' : 's'}. '
        '${positive.length} positif${positive.length == 1 ? '' : 's'}, '
        '${negative.length} négatif${negative.length == 1 ? '' : 's'}, '
        '${comments.length - positive.length - negative.length} neutre'
        '${comments.length - positive.length - negative.length == 1 ? '' : 's'}. '
        'Sujet principal : ${_truncate(postContent, 120)}';
    return DiscussionSummary(
      summary: summary,
      mainOpinions: opinions,
      frequentlyAskedQuestions: questions,
      highlights: highlights,
      source: AiSource.local,
    );
  }

  String _localTranslate(String text, CommunityLanguage target) {
    var result = text;
    final dictionary = switch (target) {
      CommunityLanguage.french => _toFrench,
      CommunityLanguage.english => _toEnglish,
      CommunityLanguage.arabic => _toArabic,
    };
    final entries = dictionary.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in entries) {
      result = result.replaceAll(
        RegExp(RegExp.escape(entry.key), caseSensitive: false),
        entry.value,
      );
    }
    return result;
  }

  // --- GEMINI ---

  Future<Map<String, dynamic>> _generateJson(
    String prompt, {
    double temperature = 0.4,
    int maxTokens = 700,
  }) async {
    final key = await _resolveApiKey();
    if (key.isEmpty) {
      throw const CommunityAiException(
        'Clé Gemini absente. Le moteur IA local est utilisé.',
      );
    }
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$model:generateContent',
      {'key': key},
    );

    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {
                'responseMimeType': 'application/json',
                'temperature': temperature,
                'maxOutputTokens': maxTokens,
              },
            }),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const CommunityAiException(
        'Gemini ne répond pas pour le moment (délai dépassé).',
      );
    } on http.ClientException {
      throw const CommunityAiException(
        'Connexion à Gemini impossible. Vérifie ta connexion Internet.',
      );
    }

    if (response.statusCode == 429) {
      throw const CommunityAiException('Quota Gemini atteint. Réessaie plus tard.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CommunityAiException(
        'Gemini a refusé la demande (HTTP ${response.statusCode}).',
      );
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw const CommunityAiException('Réponse Gemini invalide.');
    }
    final candidates = payload['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const CommunityAiException('Gemini n’a pas retourné de réponse.');
    }
    final first = candidates.first;
    final content = first is Map<String, dynamic> ? first['content'] : null;
    if (content is! Map<String, dynamic> || content['parts'] is! List) {
      throw const CommunityAiException('Réponse Gemini invalide.');
    }
    final text = (content['parts'] as List)
        .whereType<Map<String, dynamic>>()
        .map((part) => part['text'])
        .whereType<String>()
        .join()
        .trim();
    if (text.isEmpty) {
      throw const CommunityAiException('Gemini a retourné une réponse vide.');
    }
    return _decodeJsonObject(text);
  }

  Map<String, dynamic> _decodeJsonObject(String source) {
    var cleaned = source.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
    }
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start != -1 && end > start) {
      cleaned = cleaned.substring(start, end + 1);
    }
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      throw const CommunityAiException('Gemini a retourné un JSON invalide.');
    }
    throw const CommunityAiException(
      'La réponse de Gemini n’a pas le format attendu.',
    );
  }

  String _cleanText(String text) =>
      text.trim().replaceAll(RegExp(r'\n{3,}'), '\n\n');

  String _truncate(String text, int limit) {
    final trimmed = text.trim();
    if (trimmed.length <= limit) return trimmed;
    return '${trimmed.substring(0, limit - 1).trimRight()}…';
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  static const _stopWords = {
    'avec', 'pour', 'dans', 'cette', 'être', 'plus', 'mais', 'vous',
    'nous', 'tout', 'tous', 'faire', 'bien', 'jour', 'aujourd',
    'hui', 'après', 'avant', 'aussi', 'comme', 'sans', 'très', 'vraiment',
    'depuis', 'entre', 'leur', 'elle', 'elles', 'ils',
  };

  static const _positiveWords = {
    'super', 'génial', 'genial', 'bravo', 'merci', 'excellent', 'top',
    'parfait', 'bon', 'bonne', 'aime', 'adore', 'motivant', 'fiere', 'fière',
    'progrès', 'progres', 'réussi', 'reussi', 'great', 'awesome', 'love',
    'nice', 'good', 'amazing', 'perfect', 'thanks', 'thank', 'well',
  };

  static const _negativeWords = {
    'nul', 'nulle', 'horrible', 'mauvais', 'mauvaise', 'déçu', 'decu',
    'triste', 'fatigué', 'fatigue', 'douleur', 'blessé', 'blesse', 'échec',
    'echec', 'haine', 'déteste', 'deteste', 'problème', 'probleme', 'bad',
    'sad', 'hate', 'terrible', 'awful', 'worst', 'pain', 'hurt', 'tired',
  };

  static const _insultPatterns = <String, List<String>>{
    'insulte': [
      'idiot', 'idiote', 'stupide', 'imbécile', 'imbecile', 'nul', 'nulle',
      'con', 'conne', 'crétin', 'cretin', 'débile', 'debile', 'batard',
      'bâtard', 'salope', 'connard', 'abruti', 'attardé', 'attarde', 'moron',
      'stupid', 'idiot', 'dumb', 'loser', 'scum', 'bastard', 'jerk',
    ],
    'vulgaire': ['putain', 'merde', 'fdp', 'enculé', 'encule', 'fuck', 'shit'],
  };

  static const _harassmentPatterns = <String, List<String>>{
    'harcèlement': [
      'ferme ta gueule', 'tais-toi', 'dégage', 'degage', 'tu vas voir',
      'je vais te', 'on va te', 'laisse tomber', 'personne ne t’aime',
      'personne ne taime', 'shut up', 'nobody likes you', 'go away',
    ],
  };

  static const _hatePatterns = <String, List<String>>{
    'discours haineux': [
      'sale race', 'sale arabe', 'sale juif', 'sale noir', 'retourne dans ton pays',
      'sous-homme', 'sous homme', 'hate speech',
    ],
  };

  static const _violencePatterns = <String, List<String>>{
    'violence': [
      'je vais te tuer', 'je vais te frapper', 'tu vas mourir', 'à mort',
      'a mort', 'kill you', 'beat you', 'hurt you', 'death threat',
    ],
  };

  static const _explicitPatterns = <String, List<String>>{
    'contenu explicite': [
      'porno', 'porn', 'sexe explicite', 'nude', 'nudes', 'xxx',
    ],
  };

  static const _spamWords = [
    'promo', 'promotion', 'gagne', 'gratuit', 'clique', 'cliquez', 'abonne',
    'abonnez', 'follow', 'discount', 'offer', 'offre', 'whatsapp', 'telegram',
    'crypto', 'argent facile', 'lien en bio', 'lien dans la bio', 'dm moi',
    'contacte moi', 'buy now', 'achetez', 'soldes', 'concours',
  ];

  static const _toFrench = <String, String>{
    'hello': 'bonjour', 'hi': 'salut', 'great': 'génial', 'awesome': 'formidable',
    'love': 'j’adore', 'nice': 'sympa', 'good': 'bien', 'thanks': 'merci',
    'thank you': 'merci', 'yes': 'oui', 'no': 'non', 'friend': 'ami',
    'workout': 'séance', 'meal': 'repas', 'food': 'nourriture',
    'progress': 'progrès', 'health': 'santé', 'water': 'eau',
  };

  static const _toEnglish = <String, String>{
    'bonjour': 'hello', 'salut': 'hi', 'génial': 'great', 'genial': 'great',
    'formidable': 'awesome', 'j’adore': 'I love it', 'j\'adore': 'I love it',
    'sympa': 'nice', 'bien': 'good', 'merci': 'thanks', 'oui': 'yes',
    'non': 'no', 'ami': 'friend', 'séance': 'workout', 'repas': 'meal',
    'nourriture': 'food', 'progrès': 'progress', 'progres': 'progress',
    'santé': 'health', 'sante': 'health', 'eau': 'water', 'bonne': 'good',
    'bon': 'good', 'très': 'very', 'tres': 'very', 'super': 'great',
  };

  static const _toArabic = <String, String>{
    'bonjour': 'مرحبا', 'salut': 'أهلا', 'merci': 'شكرا', 'génial': 'رائع',
    'genial': 'رائع', 'super': 'ممتاز', 'bien': 'جيد', 'bon': 'جيد',
    'bonne': 'جيدة', 'oui': 'نعم', 'non': 'لا', 'ami': 'صديق',
    'séance': 'تمرين', 'seance': 'تمرين', 'repas': 'وجبة', 'nourriture': 'طعام',
    'progrès': 'تقدم', 'progres': 'تقدم', 'santé': 'صحة', 'sante': 'صحة',
    'eau': 'ماء', 'j’adore': 'أحب ذلك', 'j\'adore': 'أحب ذلك',
    'très': 'جدا', 'tres': 'جدا', 'comment': 'كيف', 'pourquoi': 'لماذا',
  };
}
