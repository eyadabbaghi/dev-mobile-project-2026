import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:fittrack_ai/events/data/demo_event_data.dart';
import 'package:fittrack_ai/events/models/sport_event.dart';
import 'package:fittrack_ai/events/widgets/events_map_view.dart';

void main() {
  testWidgets('map shows only physical events and opens a marker', (
    WidgetTester tester,
  ) async {
    SportEvent? selectedEvent;
    final events = createDemoEvents();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: EventsMapView(
              events: events,
              center: const LatLng(36.8065, 10.1815),
              isRecommended: (_) => false,
              onEventTap: (event) => selectedEvent = event,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('event-marker-demo-running')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('event-marker-demo-nutrition')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('event-marker-demo-strength')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('event-marker-demo-mobility')),
      findsNothing,
    );
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('event-marker-demo-running')));
    expect(selectedEvent?.id, 'demo-running');
  });
}
