import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/sport_event.dart';
import '../utils/event_formatters.dart';
import 'event_location_picker.dart';

class EventDetailsSheet extends StatefulWidget {
  const EventDetailsSheet({
    required this.user,
    required this.event,
    required this.onToggleRegistration,
    required this.onCheckIn,
    required this.onCancel,
    required this.onUpdateLocation,
    required this.onAddToCalendar,
    required this.onExportCalendar,
    required this.onChanged,
    super.key,
  });

  final EventUser user;
  final SportEvent event;
  final Future<String> Function(SportEvent) onToggleRegistration;
  final Future<void> Function(SportEvent, String, bool) onCheckIn;
  final Future<void> Function() onCancel;
  final Future<SportEvent> Function(SportEvent, LatLng) onUpdateLocation;
  final Future<void> Function(SportEvent) onAddToCalendar;
  final ValueChanged<SportEvent> onExportCalendar;
  final VoidCallback onChanged;

  @override
  State<EventDetailsSheet> createState() => _EventDetailsSheetState();
}

class _EventDetailsSheetState extends State<EventDetailsSheet> {
  late SportEvent _event = widget.event;

  SportEvent get event => _event;

  @override
  void didUpdateWidget(covariant EventDetailsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != widget.event.id) _event = widget.event;
  }

  @override
  Widget build(BuildContext context) {
    final isAttending = event.attendeeIds.contains(widget.user.id);
    final isWaiting = event.waitlistIds.contains(widget.user.id);
    final isEventOwner = event.coachId == widget.user.id;
    final waitlistRank = event.waitlistRank(widget.user.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (event.imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(event.imagePath!),
                  width: double.infinity,
                  height: 190,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 100,
                    child: Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(event.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [_tag(event.category.label), _tag(event.mode.label)],
            ),
            const SizedBox(height: 12),
            Text(event.description),
            const SizedBox(height: 16),
            _iconText(
              context,
              Icons.calendar_month_outlined,
              formatEventDate(event.dateTime),
            ),
            const SizedBox(height: 8),
            _iconText(
              context,
              Icons.place_outlined,
              '${event.location}, ${event.city}',
            ),
            const SizedBox(height: 8),
            _iconText(
              context,
              Icons.person_outline,
              'Coach ${event.coachName}',
            ),
            const SizedBox(height: 8),
            _iconText(
              context,
              Icons.groups_outlined,
              '${event.attendeeIds.length}/${event.capacity} inscrits · ${event.waitlistIds.length} en attente',
            ),
            if (isWaiting) ...[
              const SizedBox(height: 8),
              _iconText(
                context,
                Icons.hourglass_bottom,
                'Ta position en liste d’attente : $waitlistRank',
              ),
            ],
            const SizedBox(height: 16),
            if (isEventOwner) ...[
              if (event.mode != EventMode.online)
                OutlinedButton.icon(
                  onPressed: _updateLocation,
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  label: const Text('Ajuster le point sur la carte'),
                ),
              OutlinedButton.icon(
                onPressed: _showParticipants,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Participants et présences'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await widget.onCancel();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.event_busy_outlined),
                label: const Text('Annuler cet événement'),
              ),
            ],
            FilledButton.icon(
              onPressed: () async {
                final message = await widget.onToggleRegistration(event);
                if (!context.mounted) return;
                setState(() {});
                widget.onChanged();
                final confirmed = event.attendeeIds.contains(widget.user.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    action: confirmed
                        ? SnackBarAction(
                            label: 'Ajouter à l’agenda',
                            onPressed: () => widget.onAddToCalendar(event),
                          )
                        : null,
                  ),
                );
              },
              icon: Icon(
                isAttending || isWaiting
                    ? Icons.event_busy
                    : Icons.event_available,
              ),
              label: Text(
                isAttending
                    ? 'Se désinscrire'
                    : isWaiting
                    ? 'Quitter la liste d’attente'
                    : event.isFull
                    ? 'Rejoindre la liste d’attente'
                    : 'S’inscrire · ${event.isFree ? 'Gratuit' : '${event.price.toStringAsFixed(0)} TND'}',
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => widget.onAddToCalendar(event),
                icon: const Icon(Icons.calendar_today_outlined),
                label: const Text('Ajouter à mon agenda'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => widget.onExportCalendar(event),
              icon: const Icon(Icons.ios_share_outlined),
              label: const Text('Copier l’invitation iCal'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateLocation() async {
    final selectedPoint = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EventLocationPicker(
        initialPoint: LatLng(event.latitude, event.longitude),
      ),
    );
    if (selectedPoint == null || !mounted) return;

    final updatedEvent = await widget.onUpdateLocation(event, selectedPoint);
    if (!mounted) return;
    setState(() => _event = updatedEvent);
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Position de l’événement mise à jour.')),
    );
  }

  Future<void> _showParticipants() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, refreshSheet) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Participants · ${event.attendeeIds.length}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (event.attendeeIds.isEmpty)
              const ListTile(title: Text('Aucun participant pour le moment.')),
            ...event.attendeeIds.map(
              (id) => CheckboxListTile(
                value: event.checkedInIds.contains(id),
                title: Text(id),
                subtitle: const Text('Présence'),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (checked) async {
                  await widget.onCheckIn(event, id, checked == true);
                  if (!context.mounted) return;
                  refreshSheet(() {});
                  widget.onChanged();
                },
              ),
            ),
            if (event.waitlistIds.isNotEmpty) ...[
              const Divider(),
              Text(
                'Liste d’attente · ${event.waitlistIds.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ...event.waitlistIds.asMap().entries.map(
                (entry) => ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text('${entry.key + 1}'),
                  ),
                  title: Text(entry.value),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tag(String text) => Chip(
    label: Text(text),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Widget _iconText(BuildContext context, IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 6),
      Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
    ],
  );
}
