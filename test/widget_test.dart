import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fittrack_ai/events/data/demo_event_data.dart';
import 'package:fittrack_ai/events/data/event_database.dart';
import 'package:fittrack_ai/events/models/sport_event.dart';
import 'package:fittrack_ai/events/widgets/event_details_sheet.dart';
import 'package:fittrack_ai/main.dart';

void main() {
  setUpAll(() {
    // SQLite sur PC pour les tests, avec une base en mémoire (propre à chaque lancement).
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    EventDatabase.pathOverride = inMemoryDatabasePath;
  });

  test(
    'event image path is mapped and supported by the database schema',
    () async {
      final event = createDemoEvents().first;
      final row = event.toMap()..['image_path'] = r'C:\events\cover.jpg';
      expect(SportEvent.fromMap(row).imagePath, r'C:\events\cover.jpg');

      final db = await EventDatabase.instance.database;
      final columns = await db.rawQuery('PRAGMA table_info(events)');
      expect(columns.any((column) => column['name'] == 'image_path'), isTrue);
    },
  );

  testWidgets('events tab lists and filters demo events', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FitTrackApp());

    await tester.tap(find.byIcon(Icons.event_outlined));
    await tester.pump();
    // Laisse le temps réel à SQLite de répondre.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Run du lac : allure progressive'), findsOneWidget);
    expect(
      find.textContaining('Suggestions locales affichées'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Sousse');
    await tester.pumpAndSettle();

    expect(find.text('Mobilité et récupération'), findsOneWidget);
    expect(find.text('Run du lac : allure progressive'), findsNothing);
  });

  testWidgets('confirmed registration offers adding the event to calendar', (
    WidgetTester tester,
  ) async {
    final event = SportEvent(
      id: 'calendar-test',
      title: 'Événement test',
      description: 'Description',
      category: EventCategory.sport,
      dateTime: DateTime.now().add(const Duration(days: 1)),
      mode: EventMode.inPerson,
      city: 'Tunis',
      location: 'Parc',
      price: 0,
      capacity: 5,
      coachId: 'another-coach',
      coachName: 'Coach Test',
      latitude: 36.8,
      longitude: 10.1,
    );
    var calendarAdded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventDetailsSheet(
            event: event,
            onToggleRegistration: (target) async {
              target.attendeeIds.add(currentDemoUser.id);
              return 'Inscription confirmée.';
            },
            onCheckIn: (_, _, _) async {},
            onCancel: () async {},
            onAddToCalendar: (_) async {
              calendarAdded = true;
            },
            onExportCalendar: (_) {},
            onChanged: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.textContaining('S’inscrire'));
    await tester.pump();
    final calendarAction = find.byType(SnackBarAction);
    expect(calendarAction, findsOneWidget);

    tester.widget<SnackBarAction>(calendarAction).onPressed();
    await tester.pump();
    expect(calendarAdded, isTrue);
  });
}
