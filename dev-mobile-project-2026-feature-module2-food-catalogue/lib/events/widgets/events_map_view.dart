import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/sport_event.dart';

class EventsMapView extends StatelessWidget {
  const EventsMapView({
    required this.events,
    required this.center,
    required this.isRecommended,
    required this.onEventTap,
    super.key,
  });

  final List<SportEvent> events;
  final LatLng center;
  final bool Function(SportEvent) isRecommended;
  final ValueChanged<SportEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    final mapEvents = events
        .where((event) => event.mode != EventMode.online)
        .toList();
    final mapCoordinates = mapEvents
        .map((event) => LatLng(event.latitude, event.longitude))
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 11,
              initialCameraFit: mapCoordinates.isEmpty
                  ? null
                  : CameraFit.coordinates(
                      coordinates: mapCoordinates,
                      padding: const EdgeInsets.all(56),
                      maxZoom: 13,
                      minZoom: 5,
                    ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'tn.esprit.fittrack_ai',
              ),
              MarkerLayer(
                markers: mapEvents.map((event) {
                  final recommended = isRecommended(event);
                  final color = recommended
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.tertiary;

                  return Marker(
                    point: LatLng(event.latitude, event.longitude),
                    width: 52,
                    height: 58,
                    child: Tooltip(
                      message: event.title,
                      child: GestureDetector(
                        key: ValueKey('event-marker-${event.id}'),
                        onTap: () => onEventTap(event),
                        child: Icon(
                          Icons.location_on,
                          size: 48,
                          color: color,
                          shadows: const [
                            Shadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          if (mapEvents.isEmpty)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface
                      .withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Aucun événement avec lieu physique pour ces filtres.',
                ),
              ),
            ),
          Positioned(
            right: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface
                    .withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
