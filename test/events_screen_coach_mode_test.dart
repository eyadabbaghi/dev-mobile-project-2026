import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fittrack_ai/events/data/event_recommender.dart';
import 'package:fittrack_ai/events/data/event_repository.dart';
import 'package:fittrack_ai/events/models/sport_event.dart';
import 'package:fittrack_ai/events/screens/events_screen.dart';

import 'event_test_data.dart';

class _MemoryEventRepository extends EventRepository {
  @override
  Future<List<SportEvent>> getEvents() async => createTestEvents();
}

void main() {
  testWidgets('shows local recommendations when Gemini returns no events', (
    tester,
  ) async {
    const user = EventUser(
      id: 'user-1',
      name: 'Utilisateur',
      city: 'Tunis',
      latitude: 36.8,
      longitude: 10.1,
      activityLevel: 'Débutant',
      goals: [],
      interests: [],
    );
    final recommender = EventRecommender(
      apiKey: 'test-key',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({'recommendations': []}),
                    },
                  ],
                },
              },
            ],
          }),
          200,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventsScreen(
            user: user,
            repository: _MemoryEventRepository(),
            recommender: recommender,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Suggestions pour toi'), findsOneWidget);
    expect(find.text('Test running event'), findsOneWidget);
  });

  testWidgets('event creation button is only shown in coach mode', (
    tester,
  ) async {
    const regularUser = EventUser(
      id: 'user-1',
      name: 'Utilisateur',
      city: 'Tunis',
      latitude: 36.8,
      longitude: 10.1,
      activityLevel: 'Débutant',
      goals: [],
      interests: [],
    );
    const coach = EventUser(
      id: 'user-1',
      name: 'Utilisateur',
      city: 'Tunis',
      latitude: 36.8,
      longitude: 10.1,
      activityLevel: 'Débutant',
      goals: [],
      interests: [],
      isCoach: true,
    );

    EventsScreen screenFor(EventUser user) => EventsScreen(
      user: user,
      repository: _MemoryEventRepository(),
      recommender: EventRecommender(
        apiKey: 'test-key',
        client: MockClient(
          (_) async => throw http.ClientException('Network unavailable'),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: screenFor(regularUser))),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-event-button')), findsNothing);
    expect(
      find.textContaining('Suggestions locales affichées :'),
      findsOneWidget,
    );
    expect(find.text('Suggestions pour toi'), findsOneWidget);
    expect(find.text('Test running event'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: screenFor(coach))),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-event-button')), findsOneWidget);
  });
}
