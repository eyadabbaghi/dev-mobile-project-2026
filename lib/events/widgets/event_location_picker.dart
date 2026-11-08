import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class EventLocationPicker extends StatefulWidget {
  const EventLocationPicker({required this.initialPoint, super.key});

  final LatLng initialPoint;

  @override
  State<EventLocationPicker> createState() => _EventLocationPickerState();
}

class _EventLocationPickerState extends State<EventLocationPicker> {
  late LatLng _selectedPoint = widget.initialPoint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choisir le lieu sur la carte',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Déplace la carte et touche le point exact du rendez-vous.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.48,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: widget.initialPoint,
                        initialZoom: 14,
                        onTap: (_, point) =>
                            setState(() => _selectedPoint = point),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'tn.esprit.fittrack_ai',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedPoint,
                              width: 48,
                              height: 54,
                              child: Icon(
                                Icons.location_on,
                                size: 46,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.92,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          child: Text(
                            '© OpenStreetMap contributors',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_selectedPoint.latitude.toStringAsFixed(5)}, '
              '${_selectedPoint.longitude.toStringAsFixed(5)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, _selectedPoint),
                icon: const Icon(Icons.check),
                label: const Text('Confirmer ce point'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
