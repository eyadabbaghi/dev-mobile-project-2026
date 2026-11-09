import 'package:flutter/material.dart';

import '../models/community_reaction.dart';
import '../utils/community_formatters.dart';

class ReactionSelection {
  const ReactionSelection(this.reaction);

  final CommunityReaction? reaction;

  bool get remove => reaction == null;
}

Future<ReactionSelection?> showReactionPicker(
  BuildContext context, {
  CommunityReaction? current,
}) {
  final colors = Theme.of(context).colorScheme;
  return showModalBottomSheet<ReactionSelection>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Réagir',
              style: Theme.of(
                sheetContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final reaction in CommunityReaction.values)
                  _ReactionChoice(
                    reaction: reaction,
                    selected: current == reaction,
                    onTap: () => Navigator.pop(
                      sheetContext,
                      ReactionSelection(reaction),
                    ),
                  ),
              ],
            ),
            if (current != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      Navigator.pop(sheetContext, const ReactionSelection(null)),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(
                    'Retirer ma réaction',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ReactionChoice extends StatelessWidget {
  const _ReactionChoice({
    required this.reaction,
    required this.selected,
    required this.onTap,
  });

  final CommunityReaction reaction;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 94,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? reaction.color.withValues(alpha: 0.22)
              : colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? reaction.color
                : colors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            Text(reaction.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(
              reaction.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? reaction.color : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showReactionList(
  BuildContext context, {
  required String title,
  required List<ReactionEntry> reactions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final colors = Theme.of(sheetContext).colorScheme;
      return FractionallySizedBox(
        heightFactor: 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: reactions.isEmpty
                  ? Center(
                      child: Text(
                        'Aucune réaction pour le moment.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      itemCount: reactions.length,
                      itemBuilder: (context, index) {
                        final entry = reactions[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 17,
                            backgroundColor: entry.reaction.color.withValues(
                              alpha: 0.2,
                            ),
                            child: Text(
                              entry.reaction.emoji,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          title: Text(
                            entry.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Text(
                            entry.reaction.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: entry.reaction.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );
}
