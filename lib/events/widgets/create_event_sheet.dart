import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../data/event_location_data.dart';
import '../models/sport_event.dart';
import '../utils/event_formatters.dart';
import 'event_location_picker.dart';

class CreateEventSheet extends StatefulWidget {
  const CreateEventSheet({required this.user, super.key});

  final EventUser user;

  @override
  State<CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<CreateEventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  late final TextEditingController _city;
  final _location = TextEditingController();
  final _price = TextEditingController(text: '0');
  final _capacity = TextEditingController(text: '10');
  final _imagePicker = ImagePicker();
  XFile? _pickedImage;
  LatLng? _selectedCoordinates;
  EventCategory _category = EventCategory.sport;
  EventMode _mode = EventMode.inPerson;
  DateTime _dateTime = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    _city = TextEditingController(text: widget.user.city);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _city.dispose();
    _location.dispose();
    _price.dispose();
    _capacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      16,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Créer un événement',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Titre'),
              validator: _required,
            ),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
              minLines: 2,
              maxLines: 3,
              validator: _required,
            ),
            const SizedBox(height: 12),
            if (_pickedImage == null)
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Ajouter une photo'),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(_pickedImage!.path),
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_outlined),
                    label: const Text('Changer'),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _pickedImage = null),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Supprimer'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            DropdownButtonFormField<EventCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: EventCategory.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _category = value!),
            ),
            DropdownButtonFormField<EventMode>(
              initialValue: _mode,
              decoration: const InputDecoration(labelText: 'Mode'),
              items: EventMode.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _mode = value!),
            ),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'Ville'),
              validator: _required,
              onChanged: (_) => setState(() => _selectedCoordinates = null),
            ),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Adresse ou lien'),
              validator: _required,
            ),
            if (_mode != EventMode.online) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickMapLocation,
                icon: const Icon(Icons.map_outlined),
                label: Text(
                  _selectedCoordinates == null
                      ? 'Choisir le point sur la carte'
                      : 'Lieu sélectionné sur la carte',
                ),
              ),
              if (_selectedCoordinates != null)
                Text(
                  '${_selectedCoordinates!.latitude.toStringAsFixed(5)}, '
                  '${_selectedCoordinates!.longitude.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDateTime,
              icon: const Icon(Icons.calendar_month),
              label: Text(formatEventDate(_dateTime)),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Tarif (TND)'),
                    validator: (value) =>
                        double.tryParse((value ?? '').replaceAll(',', '.')) ==
                            null
                        ? 'Tarif invalide'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _capacity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Capacité'),
                    validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                        ? 'Capacité invalide'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.publish),
                label: const Text('Publier'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Champ obligatoire' : null;

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (image != null && mounted) {
        setState(() => _pickedImage = image);
      }
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir la galerie photo.')),
      );
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null || !mounted) return;
    setState(
      () => _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _pickMapLocation() async {
    final cityCoordinates = eventCoordinatesForCity(_city.text);
    final cityPoint = cityCoordinates == null
        ? null
        : LatLng(cityCoordinates.$1, cityCoordinates.$2);
    final initialPoint =
        _selectedCoordinates ??
        cityPoint ??
        LatLng(widget.user.latitude, widget.user.longitude);
    final selectedPoint = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EventLocationPicker(initialPoint: initialPoint),
    );
    if (selectedPoint != null && mounted) {
      setState(() => _selectedCoordinates = selectedPoint);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_mode != EventMode.online && _selectedCoordinates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choisis le point du lieu sur la carte avant de publier.',
          ),
        ),
      );
      return;
    }
    final city = _city.text.trim();
    final latitude = _selectedCoordinates?.latitude ?? widget.user.latitude;
    final longitude = _selectedCoordinates?.longitude ?? widget.user.longitude;
    Navigator.pop(
      context,
      SportEvent(
        id: 'event-${DateTime.now().microsecondsSinceEpoch}',
        title: _title.text.trim(),
        description: _description.text.trim(),
        category: _category,
        dateTime: _dateTime,
        mode: _mode,
        city: city,
        location: _location.text.trim(),
        imagePath: _pickedImage?.path,
        price: double.parse(_price.text.replaceAll(',', '.')),
        capacity: int.parse(_capacity.text),
        coachId: widget.user.id,
        coachName: widget.user.name,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }
}
