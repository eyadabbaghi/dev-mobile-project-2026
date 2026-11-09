import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fittrack_ai/events/data/event_recommender.dart';
import 'package:fittrack_ai/events/models/sport_event.dart';

import 'event_test_data.dart';

void main() {
  final events = createTestEvents();
  const profile = RecommendationProfile(
    activityLevel: 'Intermédiaire',
    goals: ['Endurance'],
    interests: ['Running'],
    city: 'Tunis',
  );

  test('keeps only up to three unique event IDs from Gemini', () async {
    final client = MockClient((request) async {
      expect(request.url.path, contains(EventRecommender.model));
      final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      final prompt =
          (requestBody['contents'] as List).first['parts'][0]['text'] as String;
      expect(prompt, contains('"activityLevel":"Intermédiaire"'));
      expect(prompt, isNot(contains('private-user-id')));
      expect(prompt, isNot(contains('Private User Name')));

      final recommendationJson = jsonEncode({
        'recommendations': [
          {'id': 'not-an-event', 'reason': 'Identifiant inventé.'},
          {'id': events[0].id, 'reason': 'Adapté à tes intérêts.'},
          {'id': events[0].id, 'reason': 'Doublon.'},
          {'id': events[1].id, 'reason': 'Un atelier à découvrir.'},
          {'id': events[2].id, 'reason': 'À distance.'},
          {'id': events[3].id, 'reason': 'Trop de recommandations.'},
        ],
      });
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': recommendationJson},
                ],
              },
            },
          ],
        }),
        200,
      );
    });
    final recommender = EventRecommender(apiKey: 'test-key', client: client);

    final result = await recommender.recommend(
      profile: profile,
      events: events,
    );

    expect(result.map((recommendation) => recommendation.event.id), [
      events[0].id,
      events[1].id,
      events[2].id,
    ]);
    expect(result.first.reason, 'Adapté à tes intérêts.');
  });

  test('reports a clear error when no API key is configured', () async {
    final recommender = EventRecommender(
      apiKey: '',
      client: MockClient((_) async => http.Response('', 200)),
    );

    await expectLater(
      recommender.recommend(profile: profile, events: events),
      throwsA(isA<EventRecommendationException>()),
    );
  });

  test('reports the Gemini quota response', () async {
    final recommender = EventRecommender(
      apiKey: 'test-key',
      client: MockClient((_) async => http.Response('', 429)),
    );

    await expectLater(
      recommender.recommend(profile: profile, events: events),
      throwsA(
        isA<EventRecommendationException>().having(
          (error) => error.message,
          'message',
          contains('Quota'),
        ),
      ),
    );
  });

  test('converts socket failures into a recommendation error', () async {
    final recommender = EventRecommender(
      apiKey: 'test-key',
      client: MockClient((_) async => throw const SocketException('offline')),
    );

    await expectLater(
      recommender.recommend(profile: profile, events: events),
      throwsA(
        isA<EventRecommendationException>().having(
          (error) => error.message,
          'message',
          contains('Connexion'),
        ),
      ),
    );
  });

  test('builds local recommendations when no AI result is available', () {
    final result = buildLocalEventRecommendations(
      events: events,
      interests: [EventCategory.running],
    );

    expect(result, hasLength(3));
    expect(result.first.event.id, events[0].id);
    expect(result.first.reason, 'Correspond à tes centres d’intérêt.');
    expect(result[1].event.id, events[4].id);
  });
}
