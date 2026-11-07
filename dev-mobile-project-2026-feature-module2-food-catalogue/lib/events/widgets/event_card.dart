import 'dart:io';

import 'package:flutter/material.dart';

import '../models/sport_event.dart';
import '../utils/event_formatters.dart';

class EventCard extends StatelessWidget {
  const EventCard({
    required this.event,
    required this.isRecommended,
    required this.onTap,
    super.key,
  });

  final SportEvent event;
  final bool isRecommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visuals = _visuals;
    final remainingPlaces = event.capacity - event.attendeeIds.length;

    return Card(
      margin: EdgeInsets.zero,
      color: colors.surface,
      elevation: 1,
      shadowColor: colors.shadow.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EventArtwork(
                event: event,
                isRecommended: isRecommended,
                remainingPlaces: remainingPlaces,
                visuals: visuals,
              ),
              const SizedBox(height: 12),
              Text(
                event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 7),
              _detailLine(
                context,
                Icons.calendar_today_outlined,
                formatEventDate(event.dateTime),
              ),
              const SizedBox(height: 4),
              _detailLine(
                context,
                event.mode == EventMode.online
                    ? Icons.videocam_outlined
                    : Icons.place_outlined,
                '${event.location} · ${event.city}',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: visuals.accent.withValues(alpha: 0.14),
                    foregroundColor: visuals.accent,
                    child: Text(
                      _initials(event.coachName),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coach',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          event.coachName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: onTap,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Détails'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _EventVisuals get _visuals => switch (event.category) {
    EventCategory.sport => const _EventVisuals(
      icon: Icons.fitness_center_rounded,
      accent: Color(0xFF087653),
      light: Color(0xFFB8E8CF),
      dark: Color(0xFF174E3D),
    ),
    EventCategory.health => const _EventVisuals(
      icon: Icons.favorite_rounded,
      accent: Color(0xFF087C92),
      light: Color(0xFFB8E7E8),
      dark: Color(0xFF174E5A),
    ),
    EventCategory.nutrition => const _EventVisuals(
      icon: Icons.restaurant_rounded,
      accent: Color(0xFF9B5100),
      light: Color(0xFFFFD6A4),
      dark: Color(0xFF693C20),
    ),
    EventCategory.running => const _EventVisuals(
      icon: Icons.directions_run_rounded,
      accent: Color(0xFF305F9E),
      light: Color(0xFFC9DCFF),
      dark: Color(0xFF233F69),
    ),
  };

  Widget _detailLine(BuildContext context, IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    ],
  );

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class _EventArtwork extends StatelessWidget {
  const _EventArtwork({
    required this.event,
    required this.isRecommended,
    required this.remainingPlaces,
    required this.visuals,
  });

  final SportEvent event;
  final bool isRecommended;
  final int remainingPlaces;
  final _EventVisuals visuals;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isFull = remainingPlaces <= 0;

    return Container(
      height: 142,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [visuals.light, visuals.accent],
        ),
      ),
      child: Stack(
        children: [
          if (event.imagePath != null) ...[
            Positioned.fill(
              child: Image.file(
                File(event.imagePath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: visuals.light,
                  child: Center(
                    child: Icon(
                      visuals.icon,
                      size: 72,
                      color: visuals.dark.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black26,
                      Colors.transparent,
                      Colors.black45,
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            Positioned(
              right: -24,
              top: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              right: 24,
              bottom: -65,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 22,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 24,
              bottom: 8,
              child: Icon(
                visuals.icon,
                size: 104,
                color: visuals.dark.withValues(alpha: 0.8),
              ),
            ),
          ],
          Positioned(
            left: 12,
            top: 12,
            child: Wrap(
              spacing: 6,
              children: [
                _ArtworkBadge(
                  label: event.category.label,
                  backgroundColor: visuals.dark.withValues(
                    alpha: event.imagePath == null ? 1 : 0.88,
                  ),
                  foregroundColor: Colors.white,
                ),
                if (isFull)
                  _ArtworkBadge(
                    label: event.waitlistIds.isEmpty
                        ? 'Complet'
                        : '${event.waitlistIds.length} en attente',
                    backgroundColor: colors.errorContainer,
                    foregroundColor: colors.onErrorContainer,
                  )
                else if (remainingPlaces <= 4)
                  _ArtworkBadge(
                    label:
                        '$remainingPlaces place${remainingPlaces == 1 ? '' : 's'}',
                    backgroundColor: colors.surface,
                    foregroundColor: visuals.dark,
                  ),
              ],
            ),
          ),
          if (isRecommended)
            Positioned(
              top: 10,
              right: 10,
              child: Tooltip(
                message: 'Suggestion selon tes centres d’intérêt',
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 17,
                    color: visuals.accent,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Row(
              children: [
                _ArtworkBadge(
                  label: event.isFree
                      ? 'Gratuit'
                      : '${event.price.toStringAsFixed(0)} TND',
                  backgroundColor: colors.surface,
                  foregroundColor: colors.onSurface,
                  bold: true,
                ),
                const SizedBox(width: 6),
                _ArtworkBadge(
                  label: event.mode.label,
                  backgroundColor: visuals.dark.withValues(
                    alpha: event.imagePath == null ? 0.86 : 0.9,
                  ),
                  foregroundColor: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtworkBadge extends StatelessWidget {
  const _ArtworkBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.bold = false,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool bold;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foregroundColor,
        fontSize: 11,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      ),
    ),
  );
}

class _EventVisuals {
  const _EventVisuals({
    required this.icon,
    required this.accent,
    required this.light,
    required this.dark,
  });

  final IconData icon;
  final Color accent;
  final Color light;
  final Color dark;
}
