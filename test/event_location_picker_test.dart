import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:fittrack_ai/events/widgets/event_location_picker.dart';

void main() {
  testWidgets('confirms the point selected on the map', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    LatLng? selectedPoint;
    const initialPoint = LatLng(36.8065, 10.1815);
    const chosenPoint = LatLng(36.85, 10.22);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selectedPoint = await showModalBottomSheet<LatLng>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) =>
                      const EventLocationPicker(initialPoint: initialPoint),
                );
              },
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.options.onTap!(
      TapPosition(const Offset(100, 100), const Offset(100, 100)),
      chosenPoint,
    );
    await tester.pump();
    await tester.tap(find.text('Confirmer ce point'));
    await tester.pumpAndSettle();

    expect(selectedPoint, chosenPoint);
  });
}
