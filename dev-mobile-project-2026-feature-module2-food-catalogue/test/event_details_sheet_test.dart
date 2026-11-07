import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fittrack_ai/events/models/sport_event.dart';
import 'package:fittrack_ai/events/widgets/event_details_sheet.dart';

void main() {
  testWidgets('event creator can manage and register for their event', (
    tester,
  ) async {
    final event = SportEvent(
      id: 'event-1',
      title: 'Course en groupe',
      description: 'Sortie ouverte à tous.',
      category: EventCategory.running,
      dateTime: DateTime(2026, 12, 1, 10),
      mode: EventMode.inPerson,
      city: 'Tunis',
      location: 'Lac',
      price: 0,
      capacity: 10,
      coachId: 'user-1',
      coachName: 'Utilisateur',
      latitude: 36.8,
      longitude: 10.1,
    );
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EventDetailsSheet(
              user: user,
              event: event,
              onToggleRegistration: (_) async => 'Inscription confirmée.',
              onCheckIn: (_, _, _) async {},
              onCancel: () async {},
              onUpdateLocation: (event, _) async => event,
              onAddToCalendar: (_) async {},
              onExportCalendar: (_) {},
              onChanged: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Participants et présences'), findsOneWidget);
    expect(find.text('Annuler cet événement'), findsOneWidget);
    expect(find.text('S’inscrire · Gratuit'), findsOneWidget);
  });
}
