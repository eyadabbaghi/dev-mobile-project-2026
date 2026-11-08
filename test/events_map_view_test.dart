import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:fittrack_ai/events/models/sport_event.dart';
import 'package:fittrack_ai/events/widgets/events_map_view.dart';

import 'event_test_data.dart';

void main() {
  testWidgets('map shows only physical events and opens a marker', (
    WidgetTester tester,
  ) async {
    SportEvent? selectedEvent;
    final events = createTestEvents();

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
      find.byKey(const ValueKey('event-marker-test-running')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('event-marker-test-hybrid')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('event-marker-test-strength')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('event-marker-test-sousse')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('event-marker-test-online')),
      findsNothing,
    );
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    expect(
      tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options
          .initialCameraFit,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('event-marker-test-sousse')));
    expect(selectedEvent?.id, 'test-sousse');
  });
}
