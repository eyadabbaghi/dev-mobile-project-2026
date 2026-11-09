import 'package:flutter/material.dart';

import '../models/community_reaction.dart';
import '../models/poll.dart';
import '../models/post.dart';
import '../utils/community_formatters.dart';
import 'reaction_picker.dart';
import 'video_attachment.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onReact,
    required this.onComment,
    required this.onEdit,
    required this.onDelete,
    required this.onPin,
    required this.onReport,
    required this.onBookmark,
    required this.onShare,
    required this.onViewReactions,
    required this.onVotePoll,
    this.onPublishDraft,
    this.onHashtagTap,
  });

  final Post post;
  final String currentUserId;
  final ValueChanged<CommunityReaction?> onReact;
  final VoidCallback onComment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPin;
  final VoidCallback onReport;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onViewReactions;
  final ValueChanged<PollOption> onVotePoll;
  final VoidCallback? onPublishDraft;
  final ValueChanged<String>? onHashtagTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isOwn = post.isOwnedBy(currentUserId);

    return Card(
      margin: EdgeInsets.zero,
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: post.isPinned
              ? colors.primary.withValues(alpha: 0.45)
              : colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, isOwn),
            const SizedBox(height: 12),
            Text(
              post.content,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            if (post.hashtags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final tag in post.hashtags)
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onHashtagTap == null
                          ? null
                          : () => onHashtagTap!(tag),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (post.imageBytes != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  post.imageBytes!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 120,
                    alignment: Alignment.center,
                    color: colors.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
            if (post.videoBytes != null) ...[
              const SizedBox(height: 12),
              CommunityVideoAttachment(
                bytes: post.videoBytes!,
                fileName: post.videoName,
              ),
            ],
            if (post.poll != null) ...[
              const SizedBox(height: 12),
              _PollView(
                poll: post.poll!,
                onVote: onVotePoll,
              ),
            ],
            const SizedBox(height: 10),
            _interactionRow(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, bool isOwn) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: Text(
            initialsOf(post.authorName),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      post.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isOwn) ...[
                    const SizedBox(width: 6),
                    _pill(
                      context,
                      'Vous',
                      colors.primary,
                    ),
                  ],
                  if (post.isPinned) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.push_pin_rounded,
                      size: 14,
                      color: colors.primary,
                    ),
                  ],
                  if (post.isDraft) ...[
                    const SizedBox(width: 6),
                    _pill(context, 'Brouillon', colors.tertiary),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${formatPostTime(post.createdAt)}'
                '${post.isEdited ? ' · modifié' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _themeBadge(context),
        PopupMenuButton<String>(
          tooltip: 'Gérer la publication',
          icon: const Icon(Icons.more_horiz),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
              case 'delete':
                onDelete();
              case 'pin':
                onPin();
              case 'report':
                onReport();
              case 'bookmark':
                onBookmark();
              case 'share':
                onShare();
              case 'publish':
                onPublishDraft?.call();
            }
          },
          itemBuilder: (context) => [
            if (post.isDraft && onPublishDraft != null)
              const PopupMenuItem(
                value: 'publish',
                child: _MenuRow(
                  icon: Icons.send_rounded,
                  label: 'Publier le brouillon',
                ),
              ),
            if (isOwn)
              const PopupMenuItem(
                value: 'edit',
                child: _MenuRow(icon: Icons.edit_outlined, label: 'Modifier'),
              ),
            if (isOwn)
              PopupMenuItem(
                value: 'pin',
                child: _MenuRow(
                  icon: post.isPinned
                      ? Icons.push_pin_outlined
                      : Icons.push_pin_rounded,
                  label: post.isPinned ? 'Désépingler' : 'Épingler',
                ),
              ),
            PopupMenuItem(
              value: 'bookmark',
              child: _MenuRow(
                icon: post.bookmarkedByMe
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                label: post.bookmarkedByMe
                    ? 'Retirer des enregistrements'
                    : 'Enregistrer',
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: _MenuRow(icon: Icons.ios_share_rounded, label: 'Partager'),
            ),
            const PopupMenuItem(
              value: 'report',
              child: _MenuRow(
                icon: Icons.flag_outlined,
                label: 'Signaler',
                color: Colors.redAccent,
              ),
            ),
            if (isOwn)
              const PopupMenuItem(
                value: 'delete',
                child: _MenuRow(
                  icon: Icons.delete_outline,
                  label: 'Supprimer',
                  color: Colors.redAccent,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _pill(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _themeBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: post.theme.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(post.theme.icon, size: 14, color: post.theme.color),
          const SizedBox(width: 5),
          Text(
            post.theme.label,
            style: TextStyle(
              color: post.theme.color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _interactionRow(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reaction = post.myReaction;
    final reactionColor = reaction?.color ?? colors.onSurfaceVariant;

    return Row(
      children: [
        _actionButton(
          context,
          icon: reaction?.emoji,
          fallbackIcon: Icons.favorite_border_rounded,
          label: '${post.reactionCount}',
          color: reaction != null ? reactionColor : null,
          onPressed: () async {
            final selection = await showReactionPicker(
              context,
              current: post.myReaction,
            );
            if (selection == null) return;
            onReact(selection.reaction);
          },
        ),
        const SizedBox(width: 2),
        _actionButton(
          context,
          icon: null,
          fallbackIcon: Icons.chat_bubble_outline_rounded,
          label: '${post.commentCount}',
          onPressed: onComment,
        ),
        const Spacer(),
        if (post.shareCount > 0)
          Text(
            '${post.shareCount} partage${post.shareCount == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        IconButton(
          tooltip: post.bookmarkedByMe ? 'Retirer' : 'Enregistrer',
          visualDensity: VisualDensity.compact,
          onPressed: onBookmark,
          icon: Icon(
            post.bookmarkedByMe
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            size: 21,
            color: post.bookmarkedByMe ? colors.primary : null,
          ),
        ),
        IconButton(
          tooltip: 'Partager',
          visualDensity: VisualDensity.compact,
          onPressed: onShare,
          icon: const Icon(Icons.ios_share_rounded, size: 20),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onViewReactions,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              post.reactionCount > 0
                  ? formatReactionList(post.reactionCounts)
                  : '',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required String? icon,
    required IconData fallbackIcon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final effectiveColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == null)
              Icon(fallbackIcon, size: 20, color: effectiveColor)
            else
              Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PollView extends StatelessWidget {
  const _PollView({required this.poll, required this.onVote});

  final PostPoll poll;
  final ValueChanged<PollOption> onVote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final showResults = poll.hasVoted || poll.isClosed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.poll_outlined, size: 17, color: colors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  poll.question,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final option in poll.options) ...[
            _PollOptionTile(
              option: option,
              percent: poll.percentageFor(option),
              showResults: showResults,
              disabled: poll.isClosed,
              onTap: () => onVote(option),
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                '${poll.totalVotes} vote${poll.totalVotes == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (poll.endsAt != null)
                Text(
                  formatPollEnd(poll.endsAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: poll.isClosed
                        ? Colors.redAccent
                        : colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PollOptionTile extends StatelessWidget {
  const _PollOptionTile({
    required this.option,
    required this.percent,
    required this.showResults,
    required this.disabled,
    required this.onTap,
  });

  final PollOption option;
  final double percent;
  final bool showResults;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: disabled ? null : onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: option.votedByMe
              ? colors.primary.withValues(alpha: 0.18)
              : colors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: option.votedByMe
                ? colors.primary.withValues(alpha: 0.7)
                : colors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (showResults)
              FractionallySizedBox(
                widthFactor: percent.clamp(0, 1),
                child: Container(
                  color: colors.primary.withValues(alpha: 0.18),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  if (option.votedByMe)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 15,
                        color: colors.primary,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: option.votedByMe
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (showResults)
                    Text(
                      '${(percent * 100).round()}% · ${option.voteCount}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurfaceVariant,
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
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(label, style: color == null ? null : TextStyle(color: color)),
      ],
    );
  }
}
