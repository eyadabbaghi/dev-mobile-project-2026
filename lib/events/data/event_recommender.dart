import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sport_event.dart';

const _configuredGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

class RecommendationProfile {
  const RecommendationProfile({
    required this.activityLevel,
    required this.goals,
    required this.interests,
    required this.city,
  });

  final String activityLevel;
  final List<String> goals;
  final List<String> interests;
  final String city;

  Map<String, Object> toJson() => {
    'activityLevel': activityLevel,
    'goals': goals,
    'interests': interests,
    'city': city,
  };
}

class EventRecommendation {
  const EventRecommendation({required this.event, required this.reason});

  final SportEvent event;
  final String reason;
}

class EventRecommendationException implements Exception {
  const EventRecommendationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EventRecommender {
  EventRecommender({String? apiKey, http.Client? client})
    : _apiKey = apiKey ?? _configuredGeminiApiKey,
      _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const model = 'gemini-3.6-flash';
  static const _timeout = Duration(seconds: 10);
  static const _maxRecommendations = 3;

  final String _apiKey;
  final http.Client _client;
  final bool _ownsClient;

  Future<List<EventRecommendation>> recommend({
    required RecommendationProfile profile,
    required List<SportEvent> events,
  }) async {
    if (events.isEmpty) return const [];
    if (_apiKey.trim().isEmpty) {
      throw const EventRecommendationException(
        'Clé Gemini absente. Configure GEMINI_API_KEY pour activer les suggestions IA.',
      );
    }

    final eventsById = {for (final event in events) event.id: event};
    final payload = {
      'profile': profile.toJson(),
      'events': events
          .map(
            (event) => {
              'id': event.id,
              'title': event.title,
              'category': event.category.label,
              'mode': event.mode.label,
              'city': event.city,
              'date': event.dateTime.toIso8601String(),
              'price': event.price,
              'remainingPlaces': event.capacity - event.attendeeIds.length,
            },
          )
          .toList(),
    };
    final prompt =
        '''
Tu aides à choisir des événements sportifs et de bien-être.
À partir du profil et de la liste JSON ci-dessous, sélectionne au maximum 3 événements à venir adaptés au profil.
Réponds uniquement en JSON avec la forme {"recommendations":[{"id":"identifiant fourni","reason":"courte explication en français"}]}.
N'invente aucun identifiant et n'inclus aucune donnée qui ne soit pas dans la liste.

${jsonEncode(payload)}
''';
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$model:generateContent',
      {'key': _apiKey},
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
                'temperature': 0.2,
                'maxOutputTokens': 512,
              },
            }),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const EventRecommendationException(
        'Gemini ne répond pas pour le moment (délai dépassé).',
      );
    } on http.ClientException {
      throw const EventRecommendationException(
        'Connexion à Gemini impossible. Vérifie ta connexion Internet.',
      );
    }

    if (response.statusCode == 429) {
      throw const EventRecommendationException(
        'Quota Gemini atteint. Réessaie plus tard.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EventRecommendationException(
        'Gemini a refusé la demande (HTTP ${response.statusCode}).',
      );
    }

    final responseJson = _decodeJsonObject(response.body);
    final candidates = responseJson['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const EventRecommendationException(
        'Gemini n’a pas retourné de recommandations.',
      );
    }

    final firstCandidate = candidates.first;
    if (firstCandidate is! Map<String, dynamic>) {
      throw const EventRecommendationException(
        'Réponse de recommandation invalide.',
      );
    }
    final content = firstCandidate['content'];
    if (content is! Map<String, dynamic> || content['parts'] is! List) {
      throw const EventRecommendationException(
        'Réponse de recommandation invalide.',
      );
    }

    final text = (content['parts'] as List)
        .whereType<Map<String, dynamic>>()
        .map((part) => part['text'])
        .whereType<String>()
        .join();
    if (text.isEmpty) {
      throw const EventRecommendationException(
        'Gemini a retourné une réponse vide.',
      );
    }

    final resultJson = _decodeJsonObject(text);
    final items = resultJson['recommendations'];
    if (items is! List) {
      throw const EventRecommendationException(
        'La liste de recommandations est invalide.',
      );
    }

    final recommendations = <EventRecommendation>[];
    final seenIds = <String>{};
    for (final item in items) {
      if (recommendations.length == _maxRecommendations) break;
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'];
      final reason = item['reason'];
      if (id is! String || reason is! String || !seenIds.add(id)) continue;
      final event = eventsById[id];
      final trimmedReason = reason.trim();
      if (event == null || trimmedReason.isEmpty) continue;

      recommendations.add(
        EventRecommendation(
          event: event,
          reason: trimmedReason.length > 180
              ? '${trimmedReason.substring(0, 177)}...'
              : trimmedReason,
        ),
      );
    }
    return recommendations;
  }

  Map<String, dynamic> _decodeJsonObject(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      throw const EventRecommendationException(
        'Gemini a retourné un JSON invalide.',
      );
    }
    throw const EventRecommendationException(
      'La réponse de Gemini n’a pas le format attendu.',
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
