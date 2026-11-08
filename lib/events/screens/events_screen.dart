import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../data/event_image_storage.dart';
import '../data/event_recommender.dart';
import '../data/event_repository.dart';
import '../models/sport_event.dart';
import '../utils/event_formatters.dart';
import '../widgets/create_event_sheet.dart';
import '../widgets/event_card.dart';
import '../widgets/event_details_sheet.dart';
import '../widgets/events_map_view.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({required this.user, super.key});

  final EventUser user;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final EventRepository _repository = EventRepository();
  final EventRecommender _recommender = EventRecommender();
  List<SportEvent> _events = [];
  List<EventRecommendation> _recommendations = [];
  bool _loading = true;
  bool _recommendationsLoading = false;
  bool _recommendationsFromAi = false;
  bool _showMap = false;
  String? _recommendationError;
  EventCategory? _category;
  String _city = 'Toutes les villes';
  int _days = 0;
  bool _freeOnly = false;
  bool _nearbyFirst = false;

  List<SportEvent> get _filteredEvents {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    final results = _events.where((event) {
      final matchesQuery =
          query.isEmpty ||
          '${event.title} ${event.coachName} ${event.city} ${event.category.label}'
              .toLowerCase()
              .contains(query);
      final matchesDate =
          event.dateTime.isAfter(now) &&
          (_days == 0 ||
              event.dateTime.isBefore(now.add(Duration(days: _days))));
      return matchesQuery &&
          (_category == null || event.category == _category) &&
          (_city == 'Toutes les villes' || event.city == _city) &&
          (!_freeOnly || event.isFree) &&
          matchesDate;
    }).toList();

    results.sort((first, second) {
      if (_nearbyFirst) {
        final distanceOrder = _distanceTo(first).compareTo(_distanceTo(second));
        if (distanceOrder != 0) return distanceOrder;
      }
      final firstRecommended = _isRecommended(first) ? 0 : 1;
      final secondRecommended = _isRecommended(second) ? 0 : 1;
      final recommendationOrder = firstRecommended.compareTo(secondRecommended);
      return recommendationOrder != 0
          ? recommendationOrder
          : first.dateTime.compareTo(second.dateTime);
    });
    return results;
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await _repository.getEvents();
    if (!mounted) return;
    setState(() {
      _events = events;
      _loading = false;
    });
    await _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    final upcomingEvents = _events
        .where((event) => event.dateTime.isAfter(DateTime.now()))
        .toList();
    setState(() {
      _recommendationsLoading = true;
      _recommendationError = null;
    });

    try {
      final recommendations = await _recommender.recommend(
        profile: RecommendationProfile(
          activityLevel: widget.user.activityLevel,
          goals: widget.user.goals,
          interests: widget.user.interests
              .map((interest) => interest.label)
              .toList(),
          city: widget.user.city,
        ),
        events: upcomingEvents,
      );
      if (!mounted) return;
      setState(() {
        _recommendations = recommendations;
        _recommendationsFromAi = true;
      });
    } on EventRecommendationException catch (error) {
      if (!mounted) return;
      setState(() {
        _recommendations = _fallbackRecommendations;
        _recommendationsFromAi = false;
        _recommendationError = error.message;
      });
    } finally {
      if (mounted) {
        setState(() => _recommendationsLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _recommender.close();
    super.dispose();
  }

  List<EventRecommendation> get _fallbackRecommendations {
    final upcomingEvents =
        _events
            .where((event) => event.dateTime.isAfter(DateTime.now()))
            .toList()
          ..sort((first, second) {
            final firstMatches = widget.user.interests.contains(first.category)
                ? 0
                : 1;
            final secondMatches =
                widget.user.interests.contains(second.category) ? 0 : 1;
            final interestOrder = firstMatches.compareTo(secondMatches);
            return interestOrder != 0
                ? interestOrder
                : first.dateTime.compareTo(second.dateTime);
          });

    return upcomingEvents.take(3).map((event) {
      final matchesInterest = widget.user.interests.contains(event.category);
      return EventRecommendation(
        event: event,
        reason: matchesInterest
            ? 'Correspond à tes centres d’intérêt.'
            : 'Événement à venir à ${event.city}.',
      );
    }).toList();
  }

  List<EventRecommendation> _recommendationsFor(
    List<SportEvent> visibleEvents,
  ) {
    final visibleIds = visibleEvents.map((event) => event.id).toSet();
    return _recommendations
        .where((recommendation) => visibleIds.contains(recommendation.event.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final events = _filteredEvents;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Communauté & événements',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Trouve ton prochain entraînement, atelier ou sortie.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  key: const ValueKey('create-event-button'),
                  onPressed: _createEvent,
                  icon: const Icon(Icons.add),
                  label: const Text('Créer'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.view_list_outlined),
                    label: Text('Liste'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.map_outlined),
                    label: Text('Carte'),
                  ),
                ],
                selected: {_showMap},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() => _showMap = selection.first);
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Événement, coach ou lieu',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer la recherche',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _categoryChip(null, 'Tout'),
                  ...EventCategory.values.map(
                    (category) => _categoryChip(category, category.label),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _filterMenu<int>(
                  label: _days == 0 ? 'Toutes les dates' : 'Dans $_days jours',
                  options: const {
                    0: 'Toutes les dates',
                    7: '7 jours',
                    30: '30 jours',
                  },
                  onSelected: (value) => setState(() => _days = value),
                ),
                _filterMenu<String>(
                  label: _city,
                  options: const {
                    'Toutes les villes': 'Toutes les villes',
                    'Tunis': 'Tunis',
                    'Sousse': 'Sousse',
                    'Ariana': 'Ariana',
                  },
                  onSelected: (value) => setState(() => _city = value),
                ),
                FilterChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('Gratuit'),
                  selected: _freeOnly,
                  onSelected: (value) => setState(() => _freeOnly = value),
                ),
                FilterChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.near_me_outlined, size: 18),
                  label: const Text('Proches'),
                  selected: _nearbyFirst,
                  onSelected: (value) => setState(() => _nearbyFirst = value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${events.length} événement${events.length == 1 ? '' : 's'}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _nearbyFirst
                      ? 'Autour de ${widget.user.city}'
                      : 'Trier par pertinence',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _showMap
                  ? EventsMapView(
                      events: events,
                      center: LatLng(
                        widget.user.latitude,
                        widget.user.longitude,
                      ),
                      isRecommended: _isRecommended,
                      onEventTap: _showEventDetails,
                    )
                  : CustomScrollView(
                      slivers: [
                        if (_recommendationsLoading ||
                            _recommendationsFor(events).isNotEmpty ||
                            (_recommendationError != null && events.isNotEmpty))
                          SliverToBoxAdapter(
                            child: _recommendationSection(context, events),
                          ),
                        if (events.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                _events.isEmpty
                                    ? 'Aucun événement pour le moment. Utilise « Créer » pour ajouter le premier.'
                                    : 'Aucun événement pour ces filtres.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.only(top: 4, bottom: 16),
                            sliver: SliverList.separated(
                              itemCount: events.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final event = events[index];
                                return EventCard(
                                  event: event,
                                  isRecommended: _isRecommended(event),
                                  onTap: () => _showEventDetails(event),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(EventCategory? category, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _category == category,
      showCheckmark: false,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: _category == category
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      selectedColor: Theme.of(context).colorScheme.primary,
      onSelected: (_) => setState(() => _category = category),
    ),
  );

  Widget _recommendationSection(
    BuildContext context,
    List<SportEvent> visibleEvents,
  ) {
    final colors = Theme.of(context).colorScheme;
    final recommendations = _recommendationsFor(visibleEvents);
    return Container(
      margin: const EdgeInsets.only(bottom: 12, top: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: colors.onPrimaryContainer,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _recommendationsFromAi
                          ? 'Suggéré par l’IA'
                          : 'Suggestions pour toi',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _recommendationsFromAi
                          ? 'Selon ton profil et les événements à venir'
                          : 'Selon tes centres d’intérêt',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (_recommendationsLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  tooltip: 'Actualiser les suggestions',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _loadRecommendations(),
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          if (_recommendationError != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Suggestions locales affichées : $_recommendationError',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ],
          if (recommendations.isNotEmpty) ...[
            const Divider(height: 18),
            for (final recommendation in recommendations)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _showEventDetails(recommendation.event),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _recommendationsFromAi
                            ? Icons.auto_awesome
                            : Icons.event_available_outlined,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recommendation.event.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              recommendation.reason,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
          ] else if (!_recommendationsLoading) ...[
            const Divider(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Aucune suggestion pour ces filtres.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterMenu<T>({
    required String label,
    required Map<T, String> options,
    required ValueChanged<T> onSelected,
  }) => PopupMenuButton<T>(
    tooltip: label,
    onSelected: onSelected,
    itemBuilder: (_) => options.entries
        .map(
          (entry) =>
              PopupMenuItem<T>(value: entry.key, child: Text(entry.value)),
        )
        .toList(),
    child: Chip(
      label: Text(label),
      avatar: const Icon(Icons.tune, size: 16),
      visualDensity: VisualDensity.compact,
    ),
  );

  bool _isRecommended(SportEvent event) => _recommendationsFromAi
      ? _recommendations.any(
          (recommendation) => recommendation.event.id == event.id,
        )
      : widget.user.interests.contains(event.category);

  double _distanceTo(SportEvent event) => distanceKm(
    widget.user.latitude,
    widget.user.longitude,
    event.latitude,
    event.longitude,
  );

  Future<void> _createEvent() async {
    final event = await showModalBottomSheet<SportEvent>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CreateEventSheet(user: widget.user),
    );
    if (event == null) return;
    try {
      final imagePath = event.imagePath == null
          ? null
          : await EventImageStorage.instance.persistImage(
              event.id,
              event.imagePath!,
            );
      final savedEvent = event.copyWithImagePath(imagePath);
      await _repository.insertEvent(savedEvent);
      if (mounted) setState(() => _events.insert(0, savedEvent));
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d’enregistrer l’événement : $error'),
        ),
      );
    }
  }

  Future<void> _showEventDetails(SportEvent event) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EventDetailsSheet(
        user: widget.user,
        event: event,
        onToggleRegistration: (target) =>
            _repository.toggleRegistration(target, widget.user.id),
        onCheckIn: _repository.setCheckedIn,
        onUpdateLocation: (target, point) async {
          final updatedEvent = await _repository.updateEventCoordinates(
            target,
            latitude: point.latitude,
            longitude: point.longitude,
          );
          if (mounted) {
            setState(() {
              final index = _events.indexWhere(
                (event) => event.id == updatedEvent.id,
              );
              if (index >= 0) _events[index] = updatedEvent;
            });
          }
          return updatedEvent;
        },
        onCancel: () async {
          await _repository.deleteEvent(event.id);
          if (mounted) setState(() => _events.remove(event));
        },
        onAddToCalendar: _addToCalendar,
        onExportCalendar: _exportCalendar,
        onChanged: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _addToCalendar(SportEvent event) async {
    try {
      final opened = await Add2Calendar.addEvent2Cal(
        Event(
          title: event.title,
          description: event.description,
          location: '${event.location}, ${event.city}',
          startDate: event.dateTime,
          endDate: event.dateTime.add(const Duration(hours: 1)),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'Agenda ouvert : confirme l’ajout de l’événement.'
                : 'Impossible d’ouvrir l’agenda sur cet appareil.',
          ),
        ),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de l’ouverture de l’agenda : ${error.message ?? error.code}',
          ),
        ),
      );
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L’agenda n’est pas disponible sur cette plateforme.'),
        ),
      );
    }
  }

  Future<void> _exportCalendar(SportEvent event) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copier l’invitation iCal'),
        content: const Text(
          'Copie le contenu iCalendar pour l’importer dans ton application de calendrier.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: event.toIcs()));
              if (context.mounted) Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Contenu iCal copié.')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copier iCal'),
          ),
        ],
      ),
    );
  }
}
